<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppInstall;
use App\Models\AppUpdateSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppUpdateController extends Controller
{
    /** Installs seen within this many days count towards the per-build breakdown. */
    private const ACTIVE_DAYS = 30;

    public function show(): JsonResponse
    {
        return ApiResponse::success($this->payload(AppUpdateSetting::current()), 'App update settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'min_build_number' => ['required', 'integer', 'min:0', 'max:2100000000'],
            'message' => ['nullable', 'string', 'max:255'],
        ], [
            'min_build_number.required' => 'Build minimum wajib diisi (0 = tidak ada update wajib).',
            'min_build_number.integer' => 'Build minimum harus berupa angka.',
            'message.max' => 'Pesan maksimal 255 karakter.',
        ]);

        $setting = AppUpdateSetting::query()->first() ?? new AppUpdateSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($this->payload($setting), 'Pengaturan update aplikasi berhasil disimpan.');
    }

    private function payload(AppUpdateSetting $setting): array
    {
        // Android only: the forced update goes through Google Play.
        $builds = AppInstall::query()
            ->where('platform', 'android')
            ->whereNotNull('build_number')
            ->where('last_seen_at', '>=', now()->subDays(self::ACTIVE_DAYS))
            ->selectRaw('build_number, MAX(app_version) as version, COUNT(*) as installs')
            ->groupBy('build_number')
            ->orderByDesc('build_number')
            ->get()
            ->map(fn ($row) => [
                'build_number' => (int) $row->build_number,
                'version' => $row->version,
                'installs' => (int) $row->installs,
            ]);

        return [
            ...$setting->toPayload(),
            'active_days' => self::ACTIVE_DAYS,
            'builds' => $builds,
        ];
    }
}
