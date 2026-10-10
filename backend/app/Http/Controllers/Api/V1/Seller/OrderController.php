<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\Store;
use App\Services\NotificationService;
use App\Services\OrderCancellationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class OrderController extends Controller
{
    public function __construct(
        private readonly OrderCancellationService $cancellationService,
        private readonly NotificationService $notificationService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $orders = $store->orders()
            ->with(['items', 'user'])
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->when($request->filled('payment_status'), fn ($q) => $q->where('payment_status', $request->string('payment_status')))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($orders, OrderResource::class, 'Orders retrieved successfully.');
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        if (! $this->authorize($request, $order)) {
            return ApiResponse::error('This order does not belong to your store.', [], 403);
        }

        $order->load(['items', 'user', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order retrieved successfully.');
    }

    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): JsonResponse
    {
        if (! $this->authorize($request, $order)) {
            return ApiResponse::error('This order does not belong to your store.', [], 403);
        }

        $nextStatus = OrderStatus::from($request->validated('status'));

        if ($nextStatus === OrderStatus::CANCELLED) {
            try {
                $order = $this->cancellationService->cancel($order, 'seller');
            } catch (RuntimeException $e) {
                return ApiResponse::error($e->getMessage(), [], 422);
            }

            $this->notifyBuyerOfStatusChange($order);

            return ApiResponse::success(new OrderResource($order), 'Order cancelled successfully.');
        }

        if (! $order->canTransitionTo($nextStatus)) {
            return ApiResponse::error('Invalid status transition.', [], 422);
        }

        $timestampField = match ($nextStatus) {
            OrderStatus::ACCEPTED => 'accepted_at',
            OrderStatus::COMPLETED => 'completed_at',
            default => null,
        };

        $order->update([
            'status' => $nextStatus,
            'status_history' => [
                ...$order->status_history,
                ['status' => $nextStatus->value, 'at' => now()->toIso8601String(), 'by' => 'seller'],
            ],
            'seller_notes' => $request->validated('seller_notes') ?? $order->seller_notes,
            ...($timestampField ? [$timestampField => now()] : []),
        ]);

        $order = $order->fresh();

        $this->notifyBuyerOfStatusChange($order);

        return ApiResponse::success(new OrderResource($order), 'Order status updated successfully.');
    }

    private function notifyBuyerOfStatusChange(Order $order): void
    {
        $statusLabels = [
            OrderStatus::ACCEPTED->value => 'diterima penjual',
            OrderStatus::PROCESSING->value => 'sedang diproses',
            OrderStatus::READY->value => 'siap dikirim/diambil',
            OrderStatus::COMPLETED->value => 'selesai',
            OrderStatus::CANCELLED->value => 'dibatalkan',
        ];

        $label = $statusLabels[$order->status->value] ?? $order->status->value;

        $this->notificationService->sendToUser(
            $order->user,
            'Status pesanan diperbarui',
            "Pesanan {$order->order_number} {$label}.",
            ['type' => 'order', 'order_id' => $order->id]
        );
    }

    public function markAsPaid(Request $request, Order $order): JsonResponse
    {
        if (! $this->authorize($request, $order)) {
            return ApiResponse::error('This order does not belong to your store.', [], 403);
        }

        if ($order->payment_status !== PaymentStatus::UNPAID) {
            return ApiResponse::error('Order is not unpaid.', [], 422);
        }

        $order->update(['payment_status' => PaymentStatus::PAID]);

        return ApiResponse::success(new OrderResource($order->fresh()), 'Order marked as paid.');
    }

    private function authorize(Request $request, Order $order): bool
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        return $order->store_id === $store->id;
    }
}
