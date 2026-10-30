<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Support\AppCache;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AppCacheController extends Controller
{
    public function index(): JsonResponse
    {
        return ApiResponse::success(['groups' => AppCache::overview()], 'App cache groups retrieved successfully.');
    }

    /** Make phones fetch the chosen groups again the next time they open the app. */
    public function invalidate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'groups' => ['required', 'array', 'min:1'],
            'groups.*' => ['string', 'distinct', Rule::in(array_keys(AppCache::GROUPS))],
        ], [
            'groups.required' => 'Pilih minimal satu cache.',
            'groups.min' => 'Pilih minimal satu cache.',
            'groups.*.in' => 'Terdapat cache yang tidak dikenal.',
        ]);

        AppCache::bump($data['groups']);

        return ApiResponse::success(['groups' => AppCache::overview()], 'Cache aplikasi berhasil disegarkan.');
    }
}
