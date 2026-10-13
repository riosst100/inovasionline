<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdminUserResource;
use App\Models\AdminUser;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AdminAuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $adminUser = AdminUser::with('role')
            ->where('email', $request->string('email')->toString())
            ->first();

        if (! $adminUser || ! Hash::check($request->string('password')->toString(), $adminUser->password)) {
            return ApiResponse::error('Kredensial login admin tidak sesuai.', [
                'login' => ['Email atau kata sandi admin salah.'],
            ], 422);
        }

        if (! $adminUser->is_active) {
            return ApiResponse::error('Akun admin Anda sedang dinonaktifkan. Hubungi Super Admin.', [], 403);
        }

        $deviceName = $request->string('device_name')->toString() ?: 'admin-portal';
        $token = $adminUser->createToken($deviceName, ['admin'])->plainTextToken;

        return ApiResponse::success([
            'user' => new AdminUserResource($adminUser),
            'token' => $token,
        ], 'Login admin berhasil.');
    }

    public function me(Request $request): JsonResponse
    {
        $adminUser = $request->user();

        if (! $adminUser instanceof AdminUser) {
            return ApiResponse::error('Unauthenticated.', [], 401);
        }

        return ApiResponse::success(new AdminUserResource($adminUser->load('role')), 'Profil admin berhasil dimuat.');
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user && method_exists($user, 'currentAccessToken')) {
            $user->currentAccessToken()?->delete();
        }

        return ApiResponse::success(null, 'Logout admin berhasil.');
    }
}
