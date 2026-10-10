<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\FaceProfileUploadRequest;
use App\Services\PhotoMatchService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FaceProfileController extends Controller
{
    public function __construct(private readonly PhotoMatchService $photoMatchService) {}

    public function store(FaceProfileUploadRequest $request): JsonResponse
    {
        $profile = $this->photoMatchService->uploadSelfie($request->user(), $request->file('selfie'));

        return ApiResponse::success([
            'id' => $profile->id,
            'status' => $profile->status,
            'selfie_url' => asset('storage/'.$profile->selfie_path),
        ], 'Selfie uploaded successfully. Matching is running in the background.', [], 201);
    }

    public function show(Request $request): JsonResponse
    {
        $profile = $request->user()->faceProfile;

        if (! $profile) {
            return ApiResponse::error('No face profile found.', [], 404);
        }

        return ApiResponse::success([
            'id' => $profile->id,
            'status' => $profile->status,
            'selfie_url' => asset('storage/'.$profile->selfie_path),
            'created_at' => $profile->created_at,
        ], 'Face profile retrieved successfully.');
    }
}
