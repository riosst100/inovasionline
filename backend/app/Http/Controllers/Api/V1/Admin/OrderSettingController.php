<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\OrderSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderSettingController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(OrderSetting::current()->toPayload(), 'Order settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'buyer_cancel_window_seconds' => ['required', 'integer', 'min:0', 'max:86400'],
        ], [
            'buyer_cancel_window_seconds.max' => 'Batas waktu maksimal 24 jam (86400 detik).',
        ]);

        $setting = OrderSetting::query()->first() ?? new OrderSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Pengaturan pesanan berhasil disimpan.');
    }
}
