<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ShippingMethodResource;
use App\Models\ShippingMethod;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShippingMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $methods = ShippingMethod::with('store')
            ->when($request->filled('store_id'), fn ($q) => $q->where('store_id', $request->string('store_id')))
            ->when($request->has('is_enabled'), fn ($q) => $q->where('is_enabled', $request->boolean('is_enabled')))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($methods, ShippingMethodResource::class, 'Shipping methods retrieved successfully.');
    }

    public function toggle(ShippingMethod $shippingMethod): JsonResponse
    {
        $shippingMethod->update(['is_enabled' => ! $shippingMethod->is_enabled]);

        return ApiResponse::success(new ShippingMethodResource($shippingMethod->fresh()), 'Shipping method updated successfully.');
    }
}
