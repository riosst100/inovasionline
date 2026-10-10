<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PhotoResource;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchedPhotoController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = $request->user()->matchedPhotos()
            ->with(['photographer', 'event'])
            ->orderByDesc('photo_matches.confidence_score')
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($paginator, PhotoResource::class, 'Matched photos retrieved successfully.');
    }
}
