<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Verification\UserVerificationRequest;
use App\Http\Resources\UserVerificationResource;
use App\Services\UserVerificationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class UserVerificationController extends Controller
{
    public function __construct(private readonly UserVerificationService $userVerificationService) {}

    public function store(UserVerificationRequest $request): JsonResponse
    {
        try {
            $verification = $this->userVerificationService->submit(
                $request->user(),
                $request->safe()->only(['full_name', 'id_number']),
                $request->file('selfie'),
                $request->file('document'),
            );
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(
            new UserVerificationResource($verification),
            'Verification submitted successfully.',
            [],
            201
        );
    }

    public function show(Request $request): JsonResponse
    {
        $verification = $request->user()->userVerifications()->latest()->first();

        if (! $verification) {
            return ApiResponse::error('No verification submission found.', [], 404);
        }

        return ApiResponse::success(new UserVerificationResource($verification), 'Verification retrieved successfully.');
    }
}
