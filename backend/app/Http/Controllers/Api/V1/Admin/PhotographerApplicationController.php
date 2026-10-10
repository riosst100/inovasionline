<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RejectPhotographerApplicationRequest;
use App\Http\Resources\PhotographerApplicationResource;
use App\Models\PhotographerApplication;
use App\Services\PhotographerApplicationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class PhotographerApplicationController extends Controller
{
    public function __construct(private readonly PhotographerApplicationService $photographerApplicationService) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = PhotographerApplication::query()
            ->when($request->string('status')->toString(), fn ($query, $status) => $query->where('status', $status))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, PhotographerApplicationResource::class, 'Photographer applications retrieved successfully.');
    }

    public function approve(Request $request, PhotographerApplication $photographerApplication): JsonResponse
    {
        try {
            $application = $this->photographerApplicationService->approve($photographerApplication, $request->user());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new PhotographerApplicationResource($application), 'Photographer application approved successfully.');
    }

    public function reject(RejectPhotographerApplicationRequest $request, PhotographerApplication $photographerApplication): JsonResponse
    {
        try {
            $application = $this->photographerApplicationService->reject($photographerApplication, $request->user(), $request->validated('reason'));
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new PhotographerApplicationResource($application), 'Photographer application rejected successfully.');
    }
}
