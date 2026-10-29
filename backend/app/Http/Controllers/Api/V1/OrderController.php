<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\MidtransService;
use App\Services\OrderCancellationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class OrderController extends Controller
{
    private const WINDOW_CLOSED = 'Batas waktu pembatalan sudah lewat, pesanan sedang dikemas.';

    public function __construct(
        private readonly OrderCancellationService $cancellationService,
        private readonly MidtransService $midtrans,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $orders = $request->user()->orders()
            ->with('items')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($orders, OrderResource::class, 'Orders retrieved successfully.');
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order retrieved successfully.');
    }

    public function cancel(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        if ($order->status === OrderStatus::PROCESSING && ! $order->buyerCanCancel()) {
            return ApiResponse::error(self::WINDOW_CLOSED, [], 422);
        }

        $wasUnpaid = $order->payment_status === PaymentStatus::UNPAID;

        try {
            // Paid orders are credited back to the buyer's balance inside cancel().
            $order = $this->cancellationService->cancel($order, 'buyer');
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        // Kill the still-open VA/QR so the cancelled order cannot be paid later.
        if ($wasUnpaid) {
            $this->midtrans->cancelTransaction($order);
        }

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order cancelled successfully.');
    }

    /** Buyer opened the cancel confirmation: pause the cancel countdown. */
    public function holdCancel(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        $order = DB::transaction(function () use ($order) {
            $order = Order::lockForUpdate()->findOrFail($order->id);

            if (! $order->buyerCanCancel()) {
                return null;
            }

            $order->startCancelHold();

            return $order;
        });

        if ($order === null) {
            return ApiResponse::error(self::WINDOW_CLOSED, [], 422);
        }

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Cancel countdown paused.');
    }

    /** Buyer backed out of cancelling: the order carries on and can no longer be cancelled. */
    public function declineCancel(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        $order = DB::transaction(function () use ($order) {
            $order = Order::lockForUpdate()->findOrFail($order->id);
            $order->declineCancel();

            return $order;
        });

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order will not be cancelled.');
    }

    /**
     * The courier's latest position for the buyer's tracking map. Only while the order is on the way:
     * before pickup and after handover the courier's whereabouts are none of the buyer's business.
     */
    public function tracking(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        $active = $order->status === OrderStatus::ON_DELIVERY && $order->driver_id !== null;
        $driver = $active ? $order->driver : null;

        return ApiResponse::success([
            'status' => $order->status->value,
            'active' => $driver !== null,
            'driver' => $driver === null ? null : [
                'name' => $driver->name,
                'phone' => $driver->phone,
                'vehicle_type' => $driver->vehicle_type,
                'vehicle_plate_number' => $driver->vehicle_plate_number,
            ],
            'location' => $driver?->last_location_at === null ? null : [
                'latitude' => $driver->last_latitude,
                'longitude' => $driver->last_longitude,
                'accuracy' => $driver->last_location_accuracy,
                'updated_at' => $driver->last_location_at->toIso8601String(),
                'seconds_ago' => (int) $driver->last_location_at->diffInSeconds(now(), true),
            ],
        ], 'Tracking retrieved successfully.');
    }
}
