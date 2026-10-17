<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ShippingMethodResource;
use App\Models\ShippingMethod;
use App\Support\Enums\ShippingMethodType;
use App\Support\Enums\ShippingRateType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShippingMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $methods = ShippingMethod::query()
            ->when($request->has('is_enabled'), fn ($q) => $q->where('is_enabled', $request->boolean('is_enabled')))
            ->withCount('deliverySchedules')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($methods, ShippingMethodResource::class, 'Shipping methods retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $method = ShippingMethod::create([
            ...$this->validated($request),
            // Admin-added methods are flat-rate; table rates are managed separately.
            'type' => ShippingMethodType::CUSTOM,
            'rate_type' => ShippingRateType::FLAT,
            'is_enabled' => $request->boolean('is_enabled', true),
            'sort_order' => (int) ShippingMethod::max('sort_order') + 1,
        ]);

        return ApiResponse::success(new ShippingMethodResource($method->fresh()->loadCount('deliverySchedules')), 'Shipping method created successfully.', [], 201);
    }

    public function update(Request $request, ShippingMethod $shippingMethod): JsonResponse
    {
        $shippingMethod->update([
            ...$this->validated($request),
            'is_enabled' => $request->boolean('is_enabled', $shippingMethod->is_enabled),
        ]);

        return ApiResponse::success(new ShippingMethodResource($shippingMethod->fresh()->loadCount('deliverySchedules')), 'Shipping method updated successfully.');
    }

    public function toggle(ShippingMethod $shippingMethod): JsonResponse
    {
        $shippingMethod->update(['is_enabled' => ! $shippingMethod->is_enabled]);

        return ApiResponse::success(new ShippingMethodResource($shippingMethod->fresh()->loadCount('deliverySchedules')), 'Shipping method updated successfully.');
    }

    public function destroy(ShippingMethod $shippingMethod): JsonResponse
    {
        // Deleting would null orders.shipping_method_id and lose the method from order history.
        if ($shippingMethod->orders()->withTrashed()->exists()) {
            return ApiResponse::error('Metode pengiriman ini sudah dipakai di pesanan. Nonaktifkan saja agar tidak muncul di checkout.', [], 422);
        }

        $shippingMethod->delete();

        return ApiResponse::success(null, 'Shipping method deleted successfully.');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:255'],
            'base_fee' => ['required', 'numeric', 'min:0'],
            'estimated_delivery_time' => ['nullable', 'string', 'max:100'],
            'free_shipping_min_amount' => ['nullable', 'numeric', 'min:0'],
            'requires_schedule' => ['required', 'boolean'],
            'schedule_days_ahead' => ['required', 'integer', 'between:1,60'],
            'is_enabled' => ['sometimes', 'boolean'],
        ]);
    }
}
