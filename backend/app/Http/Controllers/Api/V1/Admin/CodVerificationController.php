<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\CodVerificationResource;
use App\Models\CodVerification;
use App\Services\CodVerificationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/** Verifikasi COD: face recordings customers submitted before their first cash-on-delivery order. */
class CodVerificationController extends Controller
{
    public function __construct(private readonly CodVerificationService $service) {}

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'in:verified,revoked'],
            'user_id' => ['nullable', 'string', 'max:26'],
            'id' => ['nullable', 'string', 'max:26'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $paginator = CodVerification::query()
            ->with('user:id,name,email,phone')
            ->when($data['status'] ?? null, fn ($q, $status) => $q->where('status', $status))
            ->when($data['user_id'] ?? null, fn ($q, $userId) => $q->where('user_id', $userId))
            ->when($data['id'] ?? null, fn ($q, $id) => $q->whereKey($id))
            ->when($data['search'] ?? null, fn ($q, $search) => $q->whereHas('user', fn ($q) => $q
                ->where('name', 'ilike', "%{$search}%")
                ->orWhere('email', 'ilike', "%{$search}%")
                ->orWhere('phone', 'ilike', "%{$search}%")))
            ->latest()
            ->paginate($data['per_page'] ?? 20);

        return ApiResponse::paginated($paginator, CodVerificationResource::class, 'COD verifications retrieved successfully.');
    }

    public function revoke(Request $request, CodVerification $codVerification): JsonResponse
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:500']]);

        try {
            $verification = $this->service->revoke($codVerification, $data['reason']);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(
            new CodVerificationResource($verification->load('user:id,name,email,phone')),
            'COD verification revoked successfully.'
        );
    }
}
