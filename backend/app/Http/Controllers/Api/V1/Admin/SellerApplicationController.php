<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RejectSellerApplicationRequest;
use App\Http\Resources\SellerApplicationResource;
use App\Models\SellerApplication;
use App\Services\SellerApplicationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class SellerApplicationController extends Controller
{
    public function __construct(private readonly SellerApplicationService $sellerApplicationService) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = SellerApplication::query()
            ->when($request->string('status')->toString(), fn ($query, $status) => $query->where('status', $status))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, SellerApplicationResource::class, 'Seller applications retrieved successfully.');
    }

    public function approve(Request $request, SellerApplication $sellerApplication): JsonResponse
    {
        try {
            $application = $this->sellerApplicationService->approve($sellerApplication, $request->user());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new SellerApplicationResource($application), 'Seller application approved successfully.');
    }

    public function reject(RejectSellerApplicationRequest $request, SellerApplication $sellerApplication): JsonResponse
    {
        try {
            $application = $this->sellerApplicationService->reject($sellerApplication, $request->user(), $request->validated('reason'));
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new SellerApplicationResource($application), 'Seller application rejected successfully.');
    }
}
