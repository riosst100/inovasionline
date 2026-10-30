<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PublicBannerResource;
use App\Models\Banner;
use App\Models\LaunchPopupSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class LaunchPopupController extends Controller
{
    /**
     * What to show on opening the app today. `mode` is "off" whenever the schedule says
     * no (or there is nothing to show), so the app only has to follow it.
     */
    public function show(): JsonResponse
    {
        $setting = LaunchPopupSetting::current();
        $now = now(LaunchPopupSetting::TIMEZONE);
        $mode = $setting->mode;
        $items = collect();

        if (! $setting->allowsDay($now)) {
            $mode = LaunchPopupSetting::MODE_OFF;
        }

        if ($mode === LaunchPopupSetting::MODE_IMAGE) {
            $today = $now->toDateString();
            $items = Banner::query()
                ->where('placement', Banner::PLACEMENT_POPUP)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereNull('starts_on')->orWhereDate('starts_on', '<=', $today))
                ->where(fn ($q) => $q->whereNull('ends_on')->orWhereDate('ends_on', '>=', $today))
                ->orderBy('sort_order')
                ->get();

            if ($items->isEmpty()) {
                $mode = LaunchPopupSetting::MODE_OFF;
            }
        }

        return ApiResponse::success([
            'mode' => $mode,
            'max_per_day' => max(1, (int) $setting->max_per_day),
            'items' => PublicBannerResource::collection($items),
        ], 'Launch popup retrieved successfully.');
    }
}
