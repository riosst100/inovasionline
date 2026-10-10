<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

class AppVersionController extends Controller
{
    public function latest(): JsonResponse
    {
        $config = config('app_version.android');

        $apkExists = Storage::disk('public')->exists($config['apk_path']);

        return ApiResponse::success([
            'platform' => 'android',
            'version' => $config['version'],
            'build_number' => (int) $config['build_number'],
            'min_supported_build_number' => (int) $config['min_supported_build_number'],
            'force_update' => (bool) $config['force_update'],
            'release_notes' => $config['release_notes'],
            'apk_url' => $apkExists ? Storage::disk('public')->url($config['apk_path']) : null,
        ], 'Latest app version retrieved successfully.');
    }
}
