<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AdmobSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

/** Ad unit IDs and placements for the mobile app; data is null while ads are off. */
class AdmobConfigController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(AdmobSetting::current()->toAppPayload(), 'AdMob config retrieved successfully.');
    }
}
