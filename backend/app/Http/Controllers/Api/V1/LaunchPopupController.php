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
     * What to show on opening the app today (WIB): the popup images scheduled for today, else
     * the AdMob ad. The app only has to follow `mode`.
     */
    public function show(): JsonResponse
    {
        $setting = LaunchPopupSetting::current();
        $mode = $setting->mode;
        $items = collect();

        if ($mode === LaunchPopupSetting::MODE_IMAGE) {
            $now = now(LaunchPopupSetting::TIMEZONE);
            $today = $now->toDateString();

            $items = Banner::query()
                ->where('placement', Banner::PLACEMENT_POPUP)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereNull('starts_on')->orWhereDate('starts_on', '<=', $today))
                ->where(fn ($q) => $q->whereNull('ends_on')->orWhereDate('ends_on', '>=', $today))
                ->orderBy('sort_order')
                ->get()
                ->filter(fn (Banner $b) => empty($b->weekdays) || in_array($now->isoWeekday(), array_map('intval', $b->weekdays), true))
                ->values();

            // Nothing scheduled today: show the AdMob ad instead (the app shows nothing if AdMob is off).
            if ($items->isEmpty()) {
                $mode = LaunchPopupSetting::MODE_ADMOB;
            }
        }

        return ApiResponse::success([
            'mode' => $mode,
            'max_per_day' => max(1, (int) $setting->max_per_day),
            'items' => PublicBannerResource::collection($items),
        ], 'Launch popup retrieved successfully.');
    }
}
