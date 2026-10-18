<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdmobSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdmobController extends Controller
{
    /** e.g. ca-app-pub-3940256099942544/6300978111 */
    private const AD_UNIT = 'regex:/^ca-app-pub-\d{10,20}\/\d{5,15}$/';

    public function show(): JsonResponse
    {
        return ApiResponse::success(AdmobSetting::current()->toPayload(), 'AdMob settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $unit = ['nullable', 'string', 'max:64', self::AD_UNIT];

        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'android_banner_id' => $unit,
            'ios_banner_id' => $unit,
            'android_interstitial_id' => $unit,
            'ios_interstitial_id' => $unit,
            'android_rewarded_id' => $unit,
            'ios_rewarded_id' => $unit,
            'android_native_id' => $unit,
            'ios_native_id' => $unit,
            'home_banner' => ['required', 'boolean'],
            'home_bottom_banner' => ['required', 'boolean'],
            'product_list_banner' => ['required', 'boolean'],
            'product_detail_banner' => ['required', 'boolean'],
            'interstitial_enabled' => ['required', 'boolean'],
            'interstitial_every' => ['required', 'integer', 'min:1', 'max:100'],
            'bonus_requires_ad' => ['required', 'boolean'],
            'posts_native_every' => ['required', 'integer', 'min:0', 'max:50'],
        ], [
            'posts_native_every.max' => 'Jarak iklan di feed maksimal 50 postingan.',
            '*.regex' => 'Format Ad Unit ID tidak valid (contoh: ca-app-pub-1234567890123456/1234567890).',
            'interstitial_every.min' => 'Frekuensi interstitial minimal 1.',
            'interstitial_every.max' => 'Frekuensi interstitial maksimal 100.',
        ]);

        // Otherwise no one could claim the bonus: there would be no ad to watch.
        if ($data['bonus_requires_ad'] && empty($data['android_rewarded_id']) && empty($data['ios_rewarded_id'])) {
            return ApiResponse::error('Isi Ad Unit ID Rewarded sebelum mewajibkan iklan untuk bonus saldo.', [
                'bonus_requires_ad' => ['Isi Ad Unit ID Rewarded sebelum mewajibkan iklan untuk bonus saldo.'],
            ], 422);
        }

        $setting = AdmobSetting::query()->first() ?? new AdmobSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Pengaturan AdMob berhasil disimpan.');
    }
}
