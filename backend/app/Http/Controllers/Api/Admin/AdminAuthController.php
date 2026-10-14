<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Middleware\AdminTokenFromCookie;
use App\Http\Resources\AdminUserResource;
use App\Models\AdminUser;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Cookie as SymfonyCookie;

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

        $days = (int) config('admin.session_days');
        $token = $adminUser->createToken(
            $this->deviceLabel($request),
            ['admin'],
            now()->addDays($days),
        );

        $token->accessToken->forceFill([
            'ip_address' => $request->ip(),
            'user_agent' => mb_substr((string) $request->userAgent(), 0, 500),
        ])->save();

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

    /** Human readable "Browser · OS" label from the User-Agent. */
    private function deviceLabel(Request $request): string
    {
        $ua = (string) $request->userAgent();

        $browser = match (true) {
            str_contains($ua, 'Edg/') => 'Edge',
            str_contains($ua, 'OPR/') || str_contains($ua, 'Opera') => 'Opera',
            str_contains($ua, 'Firefox/') => 'Firefox',
            str_contains($ua, 'Chrome/') => 'Chrome',
            str_contains($ua, 'Safari/') => 'Safari',
            default => 'Browser',
        };

        $os = match (true) {
            str_contains($ua, 'Windows') => 'Windows',
            str_contains($ua, 'Android') => 'Android',
            str_contains($ua, 'iPhone') || str_contains($ua, 'iPad') => 'iOS',
            str_contains($ua, 'Mac OS') => 'macOS',
            str_contains($ua, 'Linux') => 'Linux',
            default => 'Unknown OS',
        };

        return "{$browser} · {$os}";
    }
}
