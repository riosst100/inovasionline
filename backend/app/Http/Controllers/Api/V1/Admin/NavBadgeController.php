<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\NavBadgeSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NavBadgeController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(NavBadgeSetting::current()->toPayload(), 'Nav badge retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'label' => ['required', 'string', 'max:16'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
        ], [
            'label.max' => 'Teks badge maksimal 16 karakter.',
            'ends_at.after' => 'Waktu selesai harus setelah waktu mulai.',
        ]);

        $setting = NavBadgeSetting::query()->first() ?? new NavBadgeSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Badge menu berhasil disimpan.');
    }
}
