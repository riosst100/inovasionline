<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\AppCache;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class CacheVersionController extends Controller
{
    /**
     * Where the app's on-phone cache stands. Served from the Laravel cache, so
     * it costs no database query; the app calls it once when it opens.
     */
    public function show(): JsonResponse
    {
        return ApiResponse::success([
            'versions' => AppCache::versions(),
            'max_age' => AppCache::maxAges(),
        ], 'Cache versions retrieved successfully.')
            ->header('Cache-Control', 'no-store');
    }
}
