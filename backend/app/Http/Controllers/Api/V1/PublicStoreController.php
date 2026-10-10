<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentMethodResource;
use App\Http\Resources\PublicProductResource;
use App\Http\Resources\PublicStoreDetailResource;
use App\Http\Resources\PublicStoreResource;
use App\Http\Resources\ShippingMethodResource;
use App\Models\Store;
use App\Services\ShippingRateResolver;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\ShippingRateType;
use App\Support\Enums\StoreStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PublicStoreController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'sort' => ['nullable', 'in:nearest,popular,newest'],
            'city_code' => ['required_if:sort,nearest', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $sort = $request->string('sort')->toString() ?: 'newest';
        $limit = $request->integer('limit', 12);

        $query = Store::query()
            ->where('status', StoreStatus::OPEN)
            ->whereNotNull('approved_at')
            ->withCount('products')
            ->withCount(['orders as order_items_sum_quantity' => function ($query) {
                $query->where('status', OrderStatus::COMPLETED);
            }]);

        match ($sort) {
            'nearest' => $this->applyNearest($query, $request->string('city_code')->toString()),
            'popular' => $query->orderByDesc('order_items_sum_quantity'),
            default => $query->orderByDesc('created_at'),
        };

        $stores = $query->limit($limit)->get();

        return ApiResponse::success(PublicStoreResource::collection($stores), 'Stores retrieved successfully.');
    }

    public function show(Request $request, string $slug): JsonResponse
    {
        $store = Store::query()
            ->where('slug', $slug)
            ->where('status', StoreStatus::OPEN)
            ->whereNotNull('approved_at')
            ->withCount('products')
            ->withCount(['orders as order_items_sum_quantity' => function ($query) {
                $query->where('status', OrderStatus::COMPLETED);
            }])
            ->with('seller')
            ->firstOrFail();

        $products = $store->products()
            ->where('status', ProductStatus::ACTIVE)
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0)])
            ->withSum(['orderItems as order_items_sum_quantity' => function ($query) {
                $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
            }], 'quantity')
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::success([
            'store' => new PublicStoreDetailResource($store),
            'products' => PublicProductResource::collection($products->items()),
        ], 'Store retrieved successfully.', [
            'current_page' => $products->currentPage(),
            'last_page' => $products->lastPage(),
            'per_page' => $products->perPage(),
            'total' => $products->total(),
        ]);
    }

    public function paymentMethods(Request $request, Store $store): JsonResponse
    {
        $methods = $store->paymentMethods()->where('is_enabled', true)->orderBy('sort_order')->get();

        return ApiResponse::success(PaymentMethodResource::collection($methods), 'Payment methods retrieved successfully.');
    }

    public function shippingMethods(Request $request, Store $store, ShippingRateResolver $resolver): JsonResponse
    {
        $request->validate([
            'district_code' => ['required', 'string'],
            'village_code' => ['nullable', 'string'],
        ]);

        $districtCode = $request->string('district_code')->toString();
        $villageCode = $request->filled('village_code') ? $request->string('village_code')->toString() : null;

        $methods = $store->shippingMethods()
            ->where('is_enabled', true)
            ->orderBy('sort_order')
            ->get()
            ->filter(function ($method) use ($resolver, $districtCode, $villageCode) {
                if ($method->rate_type === ShippingRateType::FLAT) {
                    $method->resolved_fee = (float) $method->base_fee;

                    return true;
                }

                $fee = $resolver->resolveFee($method, $districtCode, $villageCode);

                if ($fee === null) {
                    return false;
                }

                $method->resolved_fee = $fee;

                return true;
            })
            ->values();

        return ApiResponse::success(ShippingMethodResource::collection($methods), 'Shipping methods retrieved successfully.');
    }

    private function applyNearest(Builder $query, string $cityCode): void
    {
        $query->orderByRaw('city_code = ? desc', [$cityCode])
            ->orderByDesc('order_items_sum_quantity')
            ->orderByDesc('created_at');
    }
}
