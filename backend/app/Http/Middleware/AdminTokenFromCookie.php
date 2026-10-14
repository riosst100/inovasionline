<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Admin session token travels in an HttpOnly cookie. Promote it to a Bearer
 * header so Sanctum's token guard can authenticate the request.
 */
class AdminTokenFromCookie
{
    public const COOKIE = 'admin_session';

    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->bearerToken() && is_string($token = $request->cookie(self::COOKIE)) && $token !== '') {
            $request->headers->set('Authorization', 'Bearer '.$token);
        }

        return $next($request);
    }
}
