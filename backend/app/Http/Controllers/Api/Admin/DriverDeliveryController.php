<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\Order;
use App\Services\NotificationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentMethodType;
use App\Support\Enums\PaymentStatus;
use App\Support\Enums\ShippingMethodType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Endpoints for the driver app. A driver carries several parcels at once. A parcel is picked either by
 * scanning its QR (an order split into several parcels has one QR per parcel; any resolves the order)
 * or from the lists (`tab=ready` to pick up, `tab=active` to hand over); a photo then confirms the step.
 * The QR is optional on ship/deliver: when sent it must match the order.
 */
class DriverDeliveryController extends Controller
{
    public function __construct(private readonly NotificationService $notifications) {}

    /** The driver's parcels: `tab=active` (on the way, default) or `tab=done` (delivered). */
    public function index(Request $request): JsonResponse
    {
        $tab = $request->string('tab')->toString();
        $done = $tab === 'done';

        // `ready`: parcels waiting for a courier (not claimed by another driver, no store pickup).
        $query = $tab === 'ready'
            ? Order::query()
                ->where('status', OrderStatus::READY)
                ->where(fn ($q) => $q->whereNull('driver_id')->orWhere('driver_id', $request->user()->id))
                ->where('delivery_method', '!=', ShippingMethodType::STORE_PICKUP->value)
            : Order::query()
                ->where('driver_id', $request->user()->id)
                ->where('status', $done ? OrderStatus::COMPLETED : OrderStatus::ON_DELIVERY);

        $paginator = $query
            ->with(['user', 'paymentMethod'])
            ->withCount('items')
            ->orderByDesc($done ? 'completed_at' : ($tab === 'ready' ? 'updated_at' : 'shipped_at'))
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::success(
            $paginator->getCollection()->map(fn (Order $order) => $this->payload($order, $request->user()))->values(),
            'Daftar pengantaran berhasil dimuat.',
            [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        );
    }

    /** Resolves a scanned QR to its order and tells the app which step comes next. */
    public function scan(Request $request): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'string', 'max:100']]);

        $order = Order::findByQrCode($data['code']);
        if (! $order) {
            return ApiResponse::error('QR pesanan tidak dikenali.', [], 404);
        }

        return ApiResponse::success($this->payload($this->reload($order), $request->user()), 'Pesanan ditemukan.');
    }

    /** Pickup: ready -> on_delivery. Claims the parcel for this driver. */
    public function ship(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'code' => ['nullable', 'string'],
            'photo' => ['required', 'image', 'max:8192'],
        ]);

        $driver = $request->user();

        if ($error = $this->guard($order, $data['code'] ?? null)) {
            return $error;
        }
        if ($order->status !== OrderStatus::READY || $order->isStorePickup()) {
            return ApiResponse::error('Pesanan ini belum siap diantar atau tidak perlu kurir.', [], 422);
        }
        if ($order->driver_id !== null && $order->driver_id !== $driver->id) {
            return ApiResponse::error('Pesanan ini sudah diambil kurir lain.', [], 422);
        }

        $order->update([
            'driver_id' => $driver->id,
            'status' => OrderStatus::ON_DELIVERY,
            'shipped_at' => now(),
            'shipped_proof_path' => $request->file('photo')->store('delivery-proofs/shipped', 'public'),
            'status_history' => $this->history($order, OrderStatus::ON_DELIVERY, $driver),
        ]);

        $this->notifyBuyer($order, 'Pesanan Anda sedang diantar ke alamat kamu.');

        return ApiResponse::success($this->payload($this->reload($order), $driver), 'Pesanan ditandai sedang diantar.');
    }

    /** Handover: on_delivery -> completed, only by the driver who took it. */
    public function deliver(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'code' => ['nullable', 'string'],
            'photo' => ['required', 'image', 'max:8192'],
        ]);

        $driver = $request->user();

        if ($error = $this->guard($order, $data['code'] ?? null)) {
            return $error;
        }
        if ($order->status !== OrderStatus::ON_DELIVERY) {
            return ApiResponse::error('Pesanan ini tidak sedang dalam pengantaran.', [], 422);
        }
        if ($order->driver_id !== $driver->id) {
            return ApiResponse::error('Pesanan ini diantar oleh kurir lain.', [], 422);
        }

        $attributes = [
            'status' => OrderStatus::COMPLETED,
            'completed_at' => now(),
            'delivered_proof_path' => $request->file('photo')->store('delivery-proofs/delivered', 'public'),
            'status_history' => $this->history($order, OrderStatus::COMPLETED, $driver),
        ];

        // Cash is collected at the door, so the order counts as paid once it is handed over.
        $order->loadMissing('paymentMethod');
        if ($order->payment_status === PaymentStatus::UNPAID
            && $order->paymentMethod?->type === PaymentMethodType::CASH_ON_DELIVERY) {
            $attributes += ['payment_status' => PaymentStatus::PAID, 'paid_at' => now()];
        }

        $order->update($attributes);

        $this->notifyBuyer($order, 'Pesanan Anda telah selesai. Terima kasih!');

        return ApiResponse::success($this->payload($this->reload($order), $driver), 'Pesanan ditandai selesai.');
    }

    /** A scanned code, when sent, must belong to the order in the URL. */
    private function guard(Order $order, ?string $code): ?JsonResponse
    {
        if ($code === null || $code === '') {
            return null;
        }

        $scanned = Order::findByQrCode($code);

        return $scanned?->is($order) ? null : ApiResponse::error('QR tidak cocok dengan pesanan ini.', [], 422);
    }

    private function history(Order $order, OrderStatus $status, AdminUser $driver): array
    {
        return [
            ...($order->status_history ?? []),
            ['status' => $status->value, 'at' => now()->toIso8601String(), 'by' => 'driver:'.$driver->id],
        ];
    }

    private function reload(Order $order): Order
    {
        return $order->fresh(['user', 'paymentMethod'])->loadCount('items');
    }

    private function notifyBuyer(Order $order, string $body): void
    {
        $order->loadMissing('user');
        if ($order->user === null) {
            return;
        }

        try {
            $this->notifications->sendToUser($order->user, "Pesanan {$order->order_number}", $body, [
                'type' => 'order',
                'order_id' => $order->id,
            ]);
        } catch (\Throwable $e) {
            Log::warning('Driver status push failed: '.$e->getMessage());
        }
    }

    /** `next_action` is what this driver may do with the parcel next: ship, deliver or none. */
    private function payload(Order $order, AdminUser $driver): array
    {
        $address = is_array($order->delivery_address) ? $order->delivery_address : [];

        $next = match (true) {
            $order->status === OrderStatus::READY && ! $order->isStorePickup()
                && ($order->driver_id === null || $order->driver_id === $driver->id) => 'ship',
            $order->status === OrderStatus::ON_DELIVERY && $order->driver_id === $driver->id => 'deliver',
            default => 'none',
        };

        $owedInCash = $order->paymentMethod?->type === PaymentMethodType::CASH_ON_DELIVERY
            && $order->payment_status === PaymentStatus::UNPAID;

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'next_action' => $next,
            'customer_name' => $order->user?->name ?? 'Pelanggan',
            'customer_phone' => $address['recipient_phone'] ?? $order->user?->phone,
            'recipient_name' => $address['recipient_name'] ?? null,
            'address' => $address['address_line'] ?? $address['full_address'] ?? null,
            'items_count' => (int) $order->items_count,
            // Parcels the order ships in; the driver must carry all of them.
            'packages_count' => $order->packagesCount(),
            'grand_total' => (float) $order->grand_total,
            // Cash the driver must collect at the door; 0 when already paid.
            'cod_amount' => $owedInCash ? (float) $order->grand_total : 0.0,
            'customer_notes' => $order->customer_notes,
            'shipped_at' => $order->shipped_at?->toIso8601String(),
            'completed_at' => $order->completed_at?->toIso8601String(),
        ];
    }
}
