<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RejectUserVerificationRequest;
use App\Http\Resources\UserVerificationResource;
use App\Models\UserVerification;
use App\Services\UserVerificationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class UserVerificationController extends Controller
{
    public function __construct(private readonly UserVerificationService $userVerificationService) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = UserVerification::query()
            ->with('user')
            ->when($request->string('status')->toString(), fn ($query, $status) => $query->where('status', $status))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, UserVerificationResource::class, 'User verifications retrieved successfully.');
    }

    public function approve(Request $request, UserVerification $userVerification): JsonResponse
    {
        try {
            $verification = $this->userVerificationService->approve($userVerification, $request->user());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new UserVerificationResource($verification), 'User verification approved successfully.');
    }

    public function reject(RejectUserVerificationRequest $request, UserVerification $userVerification): JsonResponse
    {
        try {
            $verification = $this->userVerificationService->reject($userVerification, $request->user(), $request->validated('reason'));
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new UserVerificationResource($verification), 'User verification rejected successfully.');
    }
}
