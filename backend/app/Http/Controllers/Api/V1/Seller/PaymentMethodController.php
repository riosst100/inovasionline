<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\PaymentMethodRequest;
use App\Http\Resources\PaymentMethodResource;
use App\Models\PaymentMethod;
use App\Models\Store;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $methods = $store->paymentMethods()->orderBy('sort_order')->get();

        return ApiResponse::success(PaymentMethodResource::collection($methods), 'Payment methods retrieved successfully.');
    }

    public function store(PaymentMethodRequest $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $method = $store->paymentMethods()->create($request->validated());

        return ApiResponse::success(new PaymentMethodResource($method), 'Payment method created successfully.', [], 201);
    }

    public function update(PaymentMethodRequest $request, PaymentMethod $paymentMethod): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        if ($paymentMethod->store_id !== $store->id) {
            return ApiResponse::error('This payment method does not belong to your store.', [], 403);
        }

        $paymentMethod->update($request->validated());

        return ApiResponse::success(new PaymentMethodResource($paymentMethod), 'Payment method updated successfully.');
    }

    public function destroy(Request $request, PaymentMethod $paymentMethod): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        if ($paymentMethod->store_id !== $store->id) {
            return ApiResponse::error('This payment method does not belong to your store.', [], 403);
        }

        $paymentMethod->delete();

        return ApiResponse::success(null, 'Payment method deleted successfully.');
    }
}
