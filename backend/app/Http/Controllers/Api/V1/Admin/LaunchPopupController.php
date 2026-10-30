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
            'weekdays' => ['nullable', 'array'],
            'weekdays.*' => ['integer', 'between:1,7'],
            'max_per_day' => ['required', 'integer', 'min:1', 'max:20'],
            'starts_on' => ['nullable', 'date_format:Y-m-d'],
            'ends_on' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:starts_on'],
        ], [
            'ends_on.after_or_equal' => 'Tanggal selesai tidak boleh sebelum tanggal mulai.',
            'max_per_day.max' => 'Maksimal tampil per hari adalah 20 kali.',
        ]);

        $data['weekdays'] = empty($data['weekdays']) || count(array_unique($data['weekdays'])) === 7
            ? null
            : array_values(array_unique(array_map('intval', $data['weekdays'])));

        $setting = LaunchPopupSetting::query()->first() ?? new LaunchPopupSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Pengaturan popup berhasil disimpan.');
    }
}
