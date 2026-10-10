<?php

namespace App\Http\Middleware;

use App\Models\Store;
use App\Support\Responses\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureStoreOwnership
{
    /**
     * Resolves the authenticated seller's store and binds it to the request
     * so controllers never trust a store ID supplied by the client.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $seller = $user?->seller;

        if (! $seller) {
            return ApiResponse::error('You must be an approved seller to access this resource.', [], 403);
        }

        $store = Store::query()->where('seller_id', $seller->id)->first();

        if (! $store) {
            return ApiResponse::error('No store found for this seller account.', [], 404);
        }

        $request->attributes->set('store', $store);

        return $next($request);
    }
}
