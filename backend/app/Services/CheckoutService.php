<?php

namespace App\Services;

use App\Models\CartItem;
use App\Models\FreeShippingSetting;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderSetting;
use App\Models\PaymentMethod;
use App\Models\ProductVariant;
use App\Models\ServiceFeeSetting;
use App\Models\ShippingMethod;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentMethodType;
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
        private readonly MidtransService $midtransService,
        private readonly ProductStockService $stockService,
        private readonly DeliveryScheduleService $scheduleService,
        private readonly WalletService $walletService,
        private readonly CodVerificationService $codVerification,
        private readonly PaylaterService $paylater,
    ) {}

    public function checkout(User $user, array $validated): Order
    {
        $cart = $this->cartService->cartForUser($user);
        $cart->load(['items.product' => fn ($q) => $q->withStock(), 'items.variant']);

        $cartItemIds = $validated['cart_item_ids'] ?? null;

        $items = $cart->items
            ->when($cartItemIds !== null, fn ($items) => $items->whereIn('id', $cartItemIds))
            ->values();

        if ($items->isEmpty()) {
            throw new RuntimeException('No items in cart.');
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
            ->where('is_enabled', true)
            ->first();

        if (! $paymentMethod) {
            throw new RuntimeException('Selected payment method is not available.');
        }

        if ($paymentMethod->type === PaymentMethodType::CASH_ON_DELIVERY && ! $this->codVerification->current($user)) {
            throw new CodVerificationRequiredException;
        }

        if ($paymentMethod->type === PaymentMethodType::PAYLATER) {
            $this->paylater->assertCanUse($user);
        }

        $shippingMethod = ShippingMethod::where('id', $validated['shipping_method_id'])
            ->where('is_enabled', true)
            ->first();

        if (! $shippingMethod) {
            throw new RuntimeException('Selected shipping method is not available.');
        }

        $needsSchedule = $shippingMethod->requires_schedule;

        if ($needsSchedule && (empty($validated['delivery_schedule_id']) || empty($validated['delivery_date']))) {
            throw new RuntimeException('Silakan pilih jadwal pengiriman.');
        }

        $subtotal = $items->sum(function (CartItem $item) {
            $unitPrice = $item->variant?->price ?? $item->product->currentPrice();

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

        if (FreeShippingSetting::current()->applies((string) $paymentMethod->id, (string) $shippingMethod->id, (float) $subtotal)) {
            $shippingFee = 0.0;
        }

        $taxTotal = 0.0;
        $serviceFee = ServiceFeeSetting::current()->calculate((float) $subtotal);
        $grandTotal = $subtotal - $discountTotal + $shippingFee + $serviceFee + $taxTotal;

        // No manual confirmation step: orders go straight to preparation. Online
        // payments wait as pending until Midtrans settles them (see MidtransService).
        $initialStatus = $paymentMethod->type === PaymentMethodType::PAYMENT_GATEWAY
            ? OrderStatus::PENDING
            : OrderStatus::PROCESSING;

        $isPaylater = $paymentMethod->type === PaymentMethodType::PAYLATER;

        $order = DB::transaction(function () use ($isPaylater, $user, $validated, $items, $paymentMethod, $shippingMethod, $needsSchedule, $subtotal, $discountTotal, $shippingFee, $serviceFee, $taxTotal, $grandTotal, $initialStatus) {
            // Locks the schedule row, so concurrent checkouts cannot exceed its quota.
            $reservation = $needsSchedule
                ? $this->scheduleService->reserve($shippingMethod, $validated['delivery_schedule_id'], $validated['delivery_date'])
                : null;

            $order = Order::create([
                'order_number' => $this->generateOrderNumber(),
                'user_id' => $user->id,
                'payment_method_id' => $paymentMethod->id,
                'shipping_method_id' => $shippingMethod->id,
                'promotion_id' => null,
                'subtotal' => $subtotal,
                'discount_total' => $discountTotal,
                'shipping_fee' => $shippingFee,
                'service_fee' => $serviceFee,
                'tax_total' => $taxTotal,
                'grand_total' => $grandTotal,
                'status' => $initialStatus,
                'payment_status' => PaymentStatus::UNPAID,
                // Paylater: the bill is due this many days from now.
                'payment_expires_at' => $isPaylater ? now()->addDays((int) OrderSetting::current()->paylater_due_days) : null,
                'delivery_method' => $shippingMethod->type->value,
                'delivery_address' => $this->buildDeliveryAddress($validated),
                'delivery_schedule_id' => $reservation ? $validated['delivery_schedule_id'] : null,
                'delivery_date' => $reservation['date'] ?? null,
                'delivery_slot' => $reservation['slot'] ?? null,
                'customer_notes' => $validated['customer_notes'] ?? null,
                'status_history' => [
                    ['status' => $initialStatus->value, 'at' => now()->toIso8601String(), 'by' => 'buyer'],
                ],
            ]);

            foreach ($items as $item) {
                $unitPrice = $item->variant?->price ?? $item->product->currentPrice();

                if ($item->product_variant_id) {
                    ProductVariant::where('id', $item->product_variant_id)->decrement('stock', $item->quantity);
                    $allocations = null;
                } else {
                    // Locks the warehouse rows, so concurrent checkouts cannot oversell.
                    $allocations = $this->stockService->allocate(
                        $item->product,
                        $item->quantity,
                        $validated['district_code'] ?? null,
                        $validated['village_code'] ?? null,
                    );
                }

                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item->product_id,
                    'product_variant_id' => $item->product_variant_id,
                    'product_name' => $item->product->name,
                    'product_sku' => $item->variant?->sku ?? $item->product->sku,
                    'variant_name' => $item->variant?->name,
                    'product_image_path' => $item->product->images->first()?->path,
                    'unit_price' => $unitPrice,
                    // Cost snapshot, so later changes to the product's cost do not rewrite past profit.
                    'unit_cost' => $item->product->cost_price,
                    'quantity' => $item->quantity,
                    'stock_allocations' => $allocations,
                    'discount_amount' => 0,
                    'line_total' => (float) $unitPrice * $item->quantity,
                ]);
            }

            CartItem::whereIn('id', $items->pluck('id'))->delete();

            // Same transaction: if the balance is short, the whole order (stock, cart) rolls back.
            if ($paymentMethod->type === PaymentMethodType::WALLET) {
                $this->walletService->payForOrder($order);
                $order->update(['payment_status' => PaymentStatus::PAID, 'paid_at' => now()]);
            }

            $order = $order->fresh(['items', 'paymentMethod', 'shippingMethod']);

            return $order;
        });

        if ($paymentMethod->type === PaymentMethodType::PAYMENT_GATEWAY) {
            // The order is already persisted; if the gateway is unreachable the buyer
            // can retry through POST /orders/{order}/pay.
            try {
                $order = $this->midtransService->createSnapTransaction($order)
                    ->load(['items', 'paymentMethod', 'shippingMethod']);
            } catch (RuntimeException) {
                // intentionally ignored, see above
            }
        }

        return $order;
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
