<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentMethodResource;
use App\Http\Resources\ShippingMethodResource;
use App\Models\PaymentMethod;
use App\Models\ServiceFeeSetting;
use App\Models\ShippingMethod;
use App\Services\DeliveryScheduleService;
use App\Services\ShippingRateResolver;
use App\Support\Enums\ShippingRateType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Payment methods, shipping methods and service fee offered at checkout. */
class CheckoutOptionsController extends Controller
{
    public function serviceFee(): JsonResponse
    {
        return ApiResponse::success(ServiceFeeSetting::current()->toPayload(), 'Service fee retrieved successfully.');
    }

    public function paymentMethods(): JsonResponse
    {
        $methods = PaymentMethod::query()->where('is_enabled', true)->orderBy('sort_order')->get();

        return ApiResponse::success(PaymentMethodResource::collection($methods), 'Payment methods retrieved successfully.');
    }

    public function shippingMethods(Request $request, ShippingRateResolver $resolver): JsonResponse
    {
        $request->validate([
            'district_code' => ['required', 'string'],
            'village_code' => ['nullable', 'string'],
        ]);

        $districtCode = $request->string('district_code')->toString();
        $villageCode = $request->filled('village_code') ? $request->string('village_code')->toString() : null;

        $methods = ShippingMethod::query()
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

    /** Upcoming windows of a scheduled shipping method, grouped per day. */
    public function deliverySchedules(Request $request, DeliveryScheduleService $schedules): JsonResponse
    {
        $request->validate(['shipping_method_id' => ['required', 'string']]);

        $method = ShippingMethod::query()
            ->whereKey($request->string('shipping_method_id')->toString())
            ->where('is_enabled', true)
            ->where('requires_schedule', true)
            ->firstOrFail();

        return ApiResponse::success($schedules->upcoming($method), 'Delivery schedules retrieved successfully.');
    }
}
