<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\ServiceFeeSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ServiceFeeController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(ServiceFeeSetting::current()->toPayload(), 'Service fee retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'label' => ['required', 'string', 'max:60'],
            'type' => ['required', Rule::in(['fixed', 'percent'])],
            'value' => ['required', 'numeric', 'min:0', $request->input('type') === 'percent' ? 'max:100' : 'max:999999999'],
            'min_fee' => ['nullable', 'numeric', 'min:0'],
            'max_fee' => ['nullable', 'numeric', 'min:0', 'gte:min_fee'],
            'free_min_subtotal' => ['nullable', 'numeric', 'min:0', 'max:999999999'],
        ], [
            'value.max' => 'Nilai terlalu besar (persentase maksimal 100).',
            'max_fee.gte' => 'Biaya maksimum harus lebih besar atau sama dengan biaya minimum.',
        ]);

        $setting = ServiceFeeSetting::query()->first() ?? new ServiceFeeSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Biaya layanan berhasil disimpan.');
    }
}
