<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\ShippingMethodRequest;
use App\Http\Resources\ShippingMethodResource;
use App\Models\ShippingMethod;
use App\Models\Store;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShippingMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $methods = $store->shippingMethods()->orderBy('sort_order')->get();

        return ApiResponse::success(ShippingMethodResource::collection($methods), 'Shipping methods retrieved successfully.');
    }

    public function store(ShippingMethodRequest $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $method = $store->shippingMethods()->create($request->validated());

        return ApiResponse::success(new ShippingMethodResource($method), 'Shipping method created successfully.', [], 201);
    }

    public function update(ShippingMethodRequest $request, ShippingMethod $shippingMethod): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        if ($shippingMethod->store_id !== $store->id) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $shippingMethod->update($request->validated());

        return ApiResponse::success(new ShippingMethodResource($shippingMethod), 'Shipping method updated successfully.');
    }

    public function destroy(Request $request, ShippingMethod $shippingMethod): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        if ($shippingMethod->store_id !== $store->id) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $shippingMethod->delete();

        return ApiResponse::success(null, 'Shipping method deleted successfully.');
    }
}
