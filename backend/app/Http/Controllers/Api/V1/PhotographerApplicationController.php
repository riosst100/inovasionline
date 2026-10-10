<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\PhotographerApplicationRequest;
use App\Http\Resources\PhotographerApplicationResource;
use App\Services\PhotographerApplicationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class PhotographerApplicationController extends Controller
{
    public function __construct(private readonly PhotographerApplicationService $photographerApplicationService) {}

    public function store(PhotographerApplicationRequest $request): JsonResponse
    {
        $data = $request->validated();

        if ($request->hasFile('id_card')) {
            $data['id_card_path'] = $request->file('id_card')->store('photographer-applications', 'public');
        }

        try {
            $application = $this->photographerApplicationService->apply($request->user(), $data);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(
            new PhotographerApplicationResource($application),
            'Photographer application submitted successfully.',
            [],
            201
        );
    }

    public function show(Request $request): JsonResponse
    {
        $application = $request->user()->photographerApplications()->latest()->first();

        if (! $application) {
            return ApiResponse::error('No photographer application found.', [], 404);
        }

        return ApiResponse::success(new PhotographerApplicationResource($application), 'Photographer application retrieved successfully.');
    }
}
