<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = User::query()
            ->where('role', '!=', UserRole::PLATFORM_ADMIN->value)
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, UserResource::class, 'Daftar customer berhasil dimuat.');
    }

    public function show(User $user): JsonResponse
    {
        return ApiResponse::success(new UserResource($user), 'Detail customer berhasil dimuat.');
    }

    public function block(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'nullable|string|max:500',
        ]);

        if ($user->isPlatformAdmin()) {
            return ApiResponse::error('Akun admin tidak dapat diblokir.', [], 422);
        }

        $user->forceFill([
            'blocked_at' => now(),
            'block_reason' => $validated['reason'] ?? null,
        ])->save();

        return ApiResponse::success(new UserResource($user), 'Customer berhasil diblokir.');
    }

    public function ban(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'features' => 'required|array|min:1',
            'features.*' => ['string', \Illuminate\Validation\Rule::in(User::BANNABLE_FEATURES)],
            'reason' => 'nullable|string|max:500',
        ]);

        if ($user->isPlatformAdmin()) {
            return ApiResponse::error('Akun admin tidak dapat dibatasi.', [], 422);
        }

        $user->forceFill([
            'banned_features' => array_values(array_unique($validated['features'])),
            'ban_reason' => $validated['reason'] ?? null,
        ])->save();

        return ApiResponse::success(new UserResource($user), 'Pembatasan fitur customer berhasil disimpan.');
    }

    public function unban(User $user): JsonResponse
    {
        $user->forceFill(['banned_features' => null, 'ban_reason' => null])->save();

        return ApiResponse::success(new UserResource($user), 'Pembatasan fitur customer berhasil dicabut.');
    }

    public function unblock(User $user): JsonResponse
    {
        $user->forceFill(['blocked_at' => null, 'block_reason' => null])->save();

        return ApiResponse::success(new UserResource($user), 'Blokir customer berhasil dibuka.');
    }
}
