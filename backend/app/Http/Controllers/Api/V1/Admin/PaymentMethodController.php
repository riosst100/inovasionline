<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentMethodResource;
use App\Models\PaymentMethod;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $methods = PaymentMethod::with('store')
            ->when($request->filled('store_id'), fn ($q) => $q->where('store_id', $request->string('store_id')))
            ->when($request->has('is_enabled'), fn ($q) => $q->where('is_enabled', $request->boolean('is_enabled')))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($methods, PaymentMethodResource::class, 'Payment methods retrieved successfully.');
    }

    public function toggle(PaymentMethod $paymentMethod): JsonResponse
    {
        $paymentMethod->update(['is_enabled' => ! $paymentMethod->is_enabled]);

        return ApiResponse::success(new PaymentMethodResource($paymentMethod->fresh()), 'Payment method updated successfully.');
    }
}
