<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\LaunchPopupSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class LaunchPopupController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(LaunchPopupSetting::current()->toPayload(), 'Launch popup settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'mode' => ['required', Rule::in(LaunchPopupSetting::MODES)],
            'max_per_day' => ['required', 'integer', 'min:1', 'max:20'],
        ], [
            'max_per_day.max' => 'Maksimal tampil per hari adalah 20 kali.',
        ]);

        $setting = LaunchPopupSetting::query()->first() ?? new LaunchPopupSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Pengaturan popup berhasil disimpan.');
    }
}
