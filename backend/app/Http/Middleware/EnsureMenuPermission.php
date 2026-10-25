<?php

namespace App\Http\Middleware;

use App\Support\Permissions\AdminMenu;
use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * `menu:owner,reader,...` — reads (GET/HEAD) need view on the owner menu or on any reader menu
 * (pages that use this data as a lookup, e.g. Produk reading Supplier); writes need manage on the
 * owner. A parameter with a dot (`menu:notifications.broadcast`) is an exact permission key.
 */
class EnsureMenuPermission
{
    public function handle(Request $request, Closure $next, string $owner, string ...$readers): Response
    {
        $user = $request->user();

        if (str_contains($owner, '.')) {
            $allowed = $user->hasPermission($owner);
        } elseif ($request->isMethodSafe()) {
            $allowed = collect([$owner, ...$readers])->contains(fn (string $menu) => AdminMenu::canView($user, $menu));
        } else {
            $allowed = AdminMenu::canManage($user, $owner);
        }

        if (! $allowed) {
            return ApiResponse::error('Anda tidak punya hak akses untuk menu ini.', [], 403);
        }

        return $next($request);
    }
}
