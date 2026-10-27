<?php

namespace App\Http\Controllers\Api\Admin;

use App\Support\ImageOptimizer;
use App\Http\Controllers\Controller;
use App\Http\Middleware\AdminTokenFromCookie;
use App\Http\Resources\AdminUserResource;
use App\Models\AdminUser;
use App\Support\Responses\ApiResponse;
use App\Support\UserAgent;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Cookie as SymfonyCookie;

class AdminAuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        // Admin web and admin app sign in by username; the driver app by phone number (older driver builds by email).
        $request->validate([
            'username' => 'required_without_all:email,phone|string',
            'phone' => 'required_without_all:username,email|string',
            'email' => 'required_without_all:username,phone|email',
            'password' => 'required|string',
        ]);

        $query = AdminUser::with('role');
        if ($request->filled('username')) {
            $query->where('username', AdminUser::normalizeUsername($request->string('username')->toString()));
        } elseif ($request->filled('phone')) {
            // Phone login is for couriers only: only their phones are stored normalized.
            $query->where('phone', AdminUser::normalizePhone($request->string('phone')->toString()))
                ->whereHas('role', fn ($q) => $q->where('slug', 'driver'));
        } else {
            $query->where('email', $request->string('email')->toString());
        }
        $adminUser = $query->first();

        if (! $adminUser || ! Hash::check($request->string('password')->toString(), $adminUser->password)) {
            return ApiResponse::error('Kredensial login admin tidak sesuai.', [
                'login' => [$request->filled('phone') ? 'Nomor HP atau kata sandi salah.' : 'Username atau kata sandi salah.'],
            ], 422);
        }

        if (! $adminUser->is_active) {
            return ApiResponse::error('Akun admin Anda sedang dinonaktifkan. Hubungi Super Admin.', [], 403);
        }

        $days = (int) config('admin.session_days');
        $token = $adminUser->createToken(
            UserAgent::label($request->userAgent()),
            ['admin'],
            now()->addDays($days),
        );

        $token->accessToken->forceFill([
            'ip_address' => $request->ip(),
            'user_agent' => mb_substr((string) $request->userAgent(), 0, 500),
        ])->save();

        // The mobile admin app has no cookie jar; it gets the token itself and sends it as Bearer.
        if ($request->header('X-Client') === 'mobile') {
            return ApiResponse::success([
                'user' => new AdminUserResource($adminUser),
                'token' => $token->plainTextToken,
            ], 'Login admin berhasil.');
        }

        return ApiResponse::success([
            'user' => new AdminUserResource($adminUser),
        ], 'Login admin berhasil.')->withCookie($this->sessionCookie($token->plainTextToken, $days));
    }

    public function me(Request $request): JsonResponse
    {
        $adminUser = $request->user();

        if (! $adminUser instanceof AdminUser) {
            return ApiResponse::error('Unauthenticated.', [], 401);
        }

        $response = ApiResponse::success(new AdminUserResource($adminUser->load('role')), 'Profil admin berhasil dimuat.');

        // Sliding expiration: keep an actively used session alive for another full period.
        $token = $adminUser->currentAccessToken();
        $days = (int) config('admin.session_days');
        if ($token instanceof PersonalAccessToken && $token->expires_at?->lt(now()->addDays($days - 7))) {
            $token->forceFill(['expires_at' => now()->addDays($days)])->save();

            if ($plain = $request->cookie(AdminTokenFromCookie::COOKIE)) {
                $response->withCookie($this->sessionCookie($plain, $days));
            }
        }

        return $response;
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return ApiResponse::success(null, 'Logout admin berhasil.')->withCookie($this->forgetCookie());
    }

    public function changePassword(Request $request): JsonResponse
    {
        $adminUser = $request->user();

        if (! $adminUser instanceof AdminUser) {
            return ApiResponse::error('Unauthenticated.', [], 401);
        }

        $data = $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:8|confirmed|different:current_password',
        ]);

        if (! Hash::check($data['current_password'], $adminUser->password)) {
            return ApiResponse::error('Kata sandi saat ini salah.', [
                'current_password' => ['Kata sandi saat ini salah.'],
            ], 422);
        }

        $adminUser->forceFill(['password' => $data['password']])->save();

        // Sign out every other device; keep the one that made this request.
        $current = $adminUser->currentAccessToken();
        $adminUser->tokens()->when($current?->id, fn ($q, $id) => $q->where('id', '!=', $id))->delete();

        return ApiResponse::success(null, 'Kata sandi berhasil diubah.');
    }

    public function updateAvatar(Request $request): JsonResponse
    {
        $adminUser = $request->user();

        if (! $adminUser instanceof AdminUser) {
            return ApiResponse::error('Unauthenticated.', [], 401);
        }

        $request->validate([
            'avatar' => 'required|image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);

        $old = $adminUser->avatar_path;
        $adminUser->forceFill(['avatar_path' => ImageOptimizer::store($request->file('avatar'), 'admin-avatars', 400)])->save();

        if ($old) {
            Storage::disk('public')->delete($old);
        }

        return ApiResponse::success(new AdminUserResource($adminUser->load('role')), 'Foto profil berhasil diperbarui.');
    }

    public function deleteAvatar(Request $request): JsonResponse
    {
        $adminUser = $request->user();

        if (! $adminUser instanceof AdminUser) {
            return ApiResponse::error('Unauthenticated.', [], 401);
        }

        if ($adminUser->avatar_path) {
            Storage::disk('public')->delete($adminUser->avatar_path);
            $adminUser->forceFill(['avatar_path' => null])->save();
        }

        return ApiResponse::success(new AdminUserResource($adminUser->load('role')), 'Foto profil berhasil dihapus.');
    }

    public function sessions(Request $request): JsonResponse
    {
        $currentId = $request->user()->currentAccessToken()?->id;

        $sessions = $request->user()->tokens()
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->orderByDesc('last_used_at')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (PersonalAccessToken $t) => [
                'id' => $t->id,
                'device' => $t->name,
                'ip_address' => $t->ip_address,
                'user_agent' => $t->user_agent,
                'last_active_at' => ($t->last_used_at ?? $t->created_at)?->toIso8601String(),
                'created_at' => $t->created_at?->toIso8601String(),
                'expires_at' => $t->expires_at?->toIso8601String(),
                'is_current' => $t->id === $currentId,
            ]);

        return ApiResponse::success($sessions->values(), 'Daftar sesi aktif berhasil dimuat.');
    }

    public function revokeSession(Request $request, int $id): JsonResponse
    {
        $token = $request->user()->tokens()->whereKey($id)->first();

        if (! $token) {
            return ApiResponse::error('Sesi tidak ditemukan.', [], 404);
        }

        $isCurrent = $token->id === $request->user()->currentAccessToken()?->id;
        $token->delete();

        $response = ApiResponse::success(null, 'Sesi berhasil dihentikan.');

        return $isCurrent ? $response->withCookie($this->forgetCookie()) : $response;
    }

    public function revokeOtherSessions(Request $request): JsonResponse
    {
        $count = $request->user()->tokens()
            ->where('id', '!=', $request->user()->currentAccessToken()?->id)
            ->delete();

        return ApiResponse::success(['revoked' => $count], 'Semua sesi lain berhasil dihentikan.');
    }

    private function sessionCookie(string $value, int $days): SymfonyCookie
    {
        return Cookie::make(
            AdminTokenFromCookie::COOKIE,
            $value,
            $days * 24 * 60,
            '/',
            config('admin.cookie_domain'),
            request()->isSecure(),
            true,
            false,
            config('admin.cookie_same_site'),
        );
    }

    private function forgetCookie(): SymfonyCookie
    {
        return Cookie::forget(AdminTokenFromCookie::COOKIE, '/', config('admin.cookie_domain'));
    }
}
