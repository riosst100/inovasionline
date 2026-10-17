<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\MidtransService;
use App\Services\OrderCancellationService;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class OrderController extends Controller
{
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
}
