<?php

namespace App\Services;

use App\Models\CartItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\PaymentMethod;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\ShippingMethod;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Province;
use Laravolt\Indonesia\Models\City;
use Laravolt\Indonesia\Models\Village;
use RuntimeException;

class CheckoutService
{
    public function __construct(
        private readonly CartService $cartService,
        private readonly ShippingRateResolver $rateResolver,
        private readonly NotificationService $notificationService,
    ) {}

    public function checkout(User $user, array $validated): Order
    {
        $cart = $this->cartService->cartForUser($user);
        $cart->load(['items.product', 'items.variant']);

        $cartItemIds = $validated['cart_item_ids'] ?? null;

        $items = $cart->items
            ->filter(fn (CartItem $item) => $item->product->store_id === $validated['store_id'])
            ->when($cartItemIds !== null, fn ($items) => $items->whereIn('id', $cartItemIds))
            ->values();

        if ($items->isEmpty()) {
            throw new RuntimeException('No items in cart for this store.');
        }

        if ($cartItemIds !== null && count($cartItemIds) !== $items->count()) {
            throw new RuntimeException('Some selected items are no longer in your cart.');
        }

        foreach ($items as $item) {
            $stock = $item->variant?->stock ?? $item->product->stock;

            if ($item->quantity > $stock) {
                throw new RuntimeException("Insufficient stock for {$item->product->name}.");
            }
        }

        $paymentMethod = PaymentMethod::where('id', $validated['payment_method_id'])
            ->where('store_id', $validated['store_id'])
            ->where('is_enabled', true)
            ->first();

        if (! $paymentMethod) {
            throw new RuntimeException('Selected payment method is not available.');
        }

        $shippingMethod = ShippingMethod::where('id', $validated['shipping_method_id'])
            ->where('store_id', $validated['store_id'])
            ->where('is_enabled', true)
            ->first();

        if (! $shippingMethod) {
            throw new RuntimeException('Selected shipping method is not available.');
        }

        $subtotal = $items->sum(function (CartItem $item) {
            $unitPrice = $item->variant?->price ?? $item->product->sale_price ?? $item->product->regular_price;

            return (float) $unitPrice * $item->quantity;
        });

        $discountTotal = 0.0;

        $shippingFee = $this->rateResolver->resolveFee($shippingMethod, $validated['district_code'], $validated['village_code'] ?? null);

        if ($shippingFee === null) {
            throw new RuntimeException('Selected shipping method is not available for this address.');
        }

        if ($shippingMethod->free_shipping_min_amount !== null && $subtotal >= (float) $shippingMethod->free_shipping_min_amount) {
            $shippingFee = 0.0;
        }

        $taxTotal = 0.0;
        $grandTotal = $subtotal - $discountTotal + $shippingFee + $taxTotal;

        return DB::transaction(function () use ($user, $validated, $items, $paymentMethod, $shippingMethod, $subtotal, $discountTotal, $shippingFee, $taxTotal, $grandTotal) {
            $order = Order::create([
                'order_number' => $this->generateOrderNumber(),
                'store_id' => $validated['store_id'],
                'user_id' => $user->id,
                'payment_method_id' => $paymentMethod->id,
                'shipping_method_id' => $shippingMethod->id,
                'promotion_id' => null,
                'subtotal' => $subtotal,
                'discount_total' => $discountTotal,
                'shipping_fee' => $shippingFee,
                'tax_total' => $taxTotal,
                'grand_total' => $grandTotal,
                'status' => OrderStatus::PENDING,
                'payment_status' => PaymentStatus::UNPAID,
                'delivery_method' => $shippingMethod->type->value,
                'delivery_address' => $this->buildDeliveryAddress($validated),
                'customer_notes' => $validated['customer_notes'] ?? null,
                'status_history' => [
                    ['status' => 'pending', 'at' => now()->toIso8601String(), 'by' => 'buyer'],
                ],
            ]);

            foreach ($items as $item) {
                $unitPrice = $item->variant?->price ?? $item->product->sale_price ?? $item->product->regular_price;

                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item->product_id,
                    'product_variant_id' => $item->product_variant_id,
                    'product_name' => $item->product->name,
                    'product_sku' => $item->variant?->sku ?? $item->product->sku,
                    'variant_name' => $item->variant?->name,
                    'product_image_path' => $item->product->images->first()?->path,
                    'unit_price' => $unitPrice,
                    'quantity' => $item->quantity,
                    'discount_amount' => 0,
                    'line_total' => (float) $unitPrice * $item->quantity,
                ]);

                if ($item->product_variant_id) {
                    ProductVariant::where('id', $item->product_variant_id)->decrement('stock', $item->quantity);
                } else {
                    Product::where('id', $item->product_id)->decrement('stock', $item->quantity);
                }
            }

            CartItem::whereIn('id', $items->pluck('id'))->delete();

            $order = $order->fresh(['items', 'paymentMethod', 'shippingMethod', 'store']);

            $this->notifyStoreOfNewOrder($order);

            return $order;
        });
    }

    private function notifyStoreOfNewOrder(Order $order): void
    {
        $memberUserIds = $order->store->members()->pluck('user_id');

        foreach (User::whereIn('id', $memberUserIds)->get() as $member) {
            $this->notificationService->sendToUser(
                $member,
                'Pesanan baru masuk',
                "Pesanan {$order->order_number} senilai Rp".number_format((float) $order->grand_total, 0, ',', '.').' menunggu diproses.',
                ['type' => 'order', 'order_id' => $order->id]
            );
        }
    }

    private function generateOrderNumber(): string
    {
        do {
            $candidate = 'ORD-'.now()->format('Ymd').'-'.Str::upper(Str::random(6));
        } while (Order::where('order_number', $candidate)->exists());

        return $candidate;
    }

    private function buildDeliveryAddress(array $validated): array
    {
        return [
            'recipient_name' => $validated['recipient_name'],
            'recipient_phone' => $validated['recipient_phone'],
            'province_code' => $validated['province_code'],
            'province_name' => Province::where('code', $validated['province_code'])->value('name'),
            'city_code' => $validated['city_code'],
            'city_name' => City::where('code', $validated['city_code'])->value('name'),
            'district_code' => $validated['district_code'],
            'district_name' => District::where('code', $validated['district_code'])->value('name'),
            'village_code' => $validated['village_code'],
            'village_name' => Village::where('code', $validated['village_code'])->value('name'),
            'address_detail' => $validated['address_detail'],
        ];
    }
}
