<?php

namespace App\Http\Middleware;

use App\Models\AdminUser;
use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminAuthenticated
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! ($user instanceof AdminUser)) {
            return ApiResponse::error('Akses ditolak. Anda harus login sebagai admin.', [], 403);
        }

        if (! $user->is_active) {
            return ApiResponse::error('Akun admin Anda sedang dinonaktifkan.', [], 403);
        }

        return $next($request);
    }
}
