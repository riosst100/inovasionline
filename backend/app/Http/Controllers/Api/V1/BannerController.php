<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PublicBannerResource;
use App\Models\Banner;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class BannerController extends Controller
{
    public function index(): JsonResponse
    {
        $banners = Banner::query()->where('is_active', true)->orderBy('sort_order')->get();

        return ApiResponse::success(PublicBannerResource::collection($banners), 'Banners retrieved successfully.');
    }
}
