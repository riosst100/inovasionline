<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\MidtransService;
use App\Support\Enums\PaymentMethodType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class PaymentController extends Controller
{
    public function __construct(private readonly MidtransService $midtrans) {}

    public function pay(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        $order->load('paymentMethod');

        if ($order->paymentMethod?->type !== PaymentMethodType::PAYMENT_GATEWAY) {
            return ApiResponse::error('This order does not use online payment.', [], 422);
        }

        try {
            $order = $this->midtrans->createSnapTransaction($order);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Payment transaction ready.');
    }

    public function status(Request $request, Order $order): JsonResponse
    {
        if ($order->user_id !== $request->user()->id) {
            return ApiResponse::error('This order does not belong to you.', [], 403);
        }

        try {
            $order = $this->midtrans->syncStatus($order);
        } catch (RuntimeException $e) {
            report($e);
        }

        $order->load(['items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Payment status retrieved.');
    }

    public function notification(Request $request): JsonResponse
    {
        $payload = $request->all();

        if (! $this->midtrans->isValidSignature($payload)) {
            return response()->json(['message' => 'Invalid signature.'], 403);
        }

        try {
            $this->midtrans->handleNotification($payload);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        return response()->json(['message' => 'OK']);
    }
}
