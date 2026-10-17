<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\NavBadgeSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

/** Promo badge on the app's "Belanja Online" tab; data is null while it should not show. */
class NavBadgeController extends Controller
{
    public function show(): JsonResponse
    {
        $setting = NavBadgeSetting::current();

        return ApiResponse::success(
            $setting->isVisible() ? ['label' => $setting->label] : null,
            'Nav badge retrieved successfully.'
        );
    }
}
