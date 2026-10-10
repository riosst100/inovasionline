<?php

namespace App\Http\Middleware;

use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsPhotographer
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->photographer) {
            return ApiResponse::error('You must be an approved photographer to access this resource.', [], 403);
        }

        return $next($request);
    }
}
