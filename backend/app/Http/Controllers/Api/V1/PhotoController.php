<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PhotoResource;
use App\Models\Photo;
use App\Support\Enums\PhotoStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PhotoController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = Photo::query()
            ->where('status', PhotoStatus::PUBLISHED)
            ->when($request->string('photo_event_id')->toString(), fn ($query, $eventId) => $query->where('photo_event_id', $eventId))
            ->with(['photographer', 'event'])
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($paginator, PhotoResource::class, 'Photos retrieved successfully.');
    }

    public function show(Photo $photo): JsonResponse
    {
        $photo->load(['photographer', 'event']);

        return ApiResponse::success(new PhotoResource($photo), 'Photo retrieved successfully.');
    }
}
