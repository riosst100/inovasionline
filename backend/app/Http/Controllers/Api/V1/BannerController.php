<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PublicBannerResource;
use App\Models\Banner;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BannerController extends Controller
{
    /**
     * Active banners of one placement (`?placement=popup`). Defaults to the hero slider, which is all
     * that app versions without the popup ask for.
     */
    public function index(Request $request): JsonResponse
    {
        $placement = in_array($request->query('placement'), Banner::PLACEMENTS, true)
            ? $request->query('placement')
            : Banner::PLACEMENT_SLIDER;

        $banners = Banner::query()
            ->where('placement', $placement)
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->get();

        // Rarely changes; a short shared-cache window spares the DB on every app open.
        return ApiResponse::success(PublicBannerResource::collection($banners), 'Banners retrieved successfully.')
            ->header('Cache-Control', 'public, max-age=60');
    }
}
