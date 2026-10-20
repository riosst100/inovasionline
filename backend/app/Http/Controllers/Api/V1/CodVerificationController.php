<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\CodVerificationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class CodVerificationController extends Controller
{
    public function __construct(private readonly CodVerificationService $service) {}

    public function show(Request $request): JsonResponse
    {
        $verification = $this->service->current($request->user());

        return ApiResponse::success([
            'verified' => $verification !== null,
            'verified_at' => $verification?->created_at,
        ], 'Face verification status retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'video' => ['required', 'file', 'mimetypes:video/mp4,video/quicktime,video/3gpp,video/webm,video/x-matroska', 'max:9000'],
            'steps' => ['required', 'array'],
            'steps.*' => ['string', 'max:30'],
            'device' => ['nullable', 'string', 'max:255'],
        ]);

        try {
            $this->service->submit(
                $request->user(),
                $request->file('video'),
                $data['steps'],
                $data['device'] ?? null,
                $request->ip(),
            );
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(['verified' => true, 'verified_at' => now()], 'Verifikasi wajah berhasil.', [], 201);
    }
}
