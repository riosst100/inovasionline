<?php

namespace App\Http\Middleware;

use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Lets only accounts allowed to update deliveries (the driver role) through. */
class EnsureDriver
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user()?->hasPermission('delivery.update')) {
            return ApiResponse::error('Akun ini bukan driver.', [], 403);
        }

        return $next($request);
    }
}
