<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $orders = Order::with(['store', 'user'])
            ->when($request->filled('store_id'), fn ($q) => $q->where('store_id', $request->string('store_id')))
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->when($request->filled('payment_status'), fn ($q) => $q->where('payment_status', $request->string('payment_status')))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($orders, OrderResource::class, 'Orders retrieved successfully.');
    }

    public function show(Order $order): JsonResponse
    {
        $order->load(['store', 'user', 'items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order retrieved successfully.');
    }
}
