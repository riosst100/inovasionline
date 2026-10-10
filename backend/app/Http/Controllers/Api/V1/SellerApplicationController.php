<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\SellerApplicationRequest;
use App\Http\Resources\SellerApplicationResource;
use App\Services\SellerApplicationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class SellerApplicationController extends Controller
{
    public function __construct(private readonly SellerApplicationService $sellerApplicationService) {}

    public function store(SellerApplicationRequest $request): JsonResponse
    {
        try {
            $application = $this->sellerApplicationService->apply($request->user(), $request->validated());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(
            new SellerApplicationResource($application),
            'Seller application submitted successfully.',
            [],
            201
        );
    }

    public function show(Request $request): JsonResponse
    {
        $application = $request->user()->sellerApplications()->latest()->first();

        if (! $application) {
            return ApiResponse::error('No seller application found.', [], 404);
        }

        return ApiResponse::success(new SellerApplicationResource($application), 'Seller application retrieved successfully.');
    }
}
