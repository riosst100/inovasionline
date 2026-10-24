<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppUpdateSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

/**
 * Update policy for the customer app. The update itself comes from Google Play;
 * builds below min_build_number must update before they can be used.
 */
class AppVersionController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(AppUpdateSetting::current()->toPayload(), 'App update policy retrieved successfully.');
    }
}
