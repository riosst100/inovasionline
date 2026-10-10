<?php

namespace App\Http\Controllers\Api\V1\Photographer;

use App\Http\Controllers\Controller;
use App\Http\Requests\Photographer\PhotoUploadRequest;
use App\Http\Resources\PhotoResource;
use App\Models\Photo;
use App\Services\PhotoMatchService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PhotoController extends Controller
{
    public function __construct(private readonly PhotoMatchService $photoMatchService) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $request->user()->photographer->photos()
            ->with('event')
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($paginator, PhotoResource::class, 'Photos retrieved successfully.');
    }

    public function store(PhotoUploadRequest $request): JsonResponse
    {
        $photo = $this->photoMatchService->uploadPhoto(
            $request->user()->photographer,
            $request->file('photo'),
            $request->validated()
        );

        return ApiResponse::success(new PhotoResource($photo), 'Photo uploaded successfully. Face matching is running in the background.', [], 201);
    }

    public function destroy(Photo $photo): JsonResponse
    {
        $photo->delete();

        return ApiResponse::success(null, 'Photo deleted successfully.');
    }
}
