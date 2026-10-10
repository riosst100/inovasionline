<?php

namespace App\Http\Middleware;

use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || $user->role !== UserRole::PLATFORM_ADMIN) {
            return ApiResponse::error('You must be a platform admin to access this resource.', [], 403);
        }

        return $next($request);
    }
}
