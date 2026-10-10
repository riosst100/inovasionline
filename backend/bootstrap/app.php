<?php

use App\Support\Responses\ApiResponse;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Auth\Middleware\Authenticate;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['middleware' => ['api', 'auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // This is an API-only app with no named "login" route. Without this,
        // Authenticate::redirectTo() calls route('login') for any request
        // that doesn't satisfy expectsJson(), throwing a RouteNotFoundException
        // instead of the clean 401 JSON response handled below.
        Authenticate::redirectUsing(fn () => null);

        $middleware->statefulApi();

        $middleware->api(prepend: [
            \Illuminate\Http\Middleware\HandleCors::class,
        ]);

        $middleware->api(append: [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Session\Middleware\StartSession::class,
        ]);

        $middleware->alias([
            'store.owner' => \App\Http\Middleware\EnsureStoreOwnership::class,
            'seller' => \App\Http\Middleware\EnsureUserIsSeller::class,
            'admin' => \App\Http\Middleware\EnsureUserIsAdmin::class,
            'photographer' => \App\Http\Middleware\EnsureUserIsPhotographer::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(function (Request $request, Throwable $e) {
            return $request->is('api/*') || $request->expectsJson();
        });

        $exceptions->render(function (ValidationException $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiResponse::error('Validation failed.', $e->errors(), 422);
            }
        });

        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiResponse::error('Unauthenticated.', [], 401);
            }
        });

        $exceptions->render(function (\Illuminate\Auth\Access\AuthorizationException $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiResponse::error($e->getMessage() ?: 'This action is unauthorized.', [], 403);
            }
        });

        $exceptions->render(function (\Illuminate\Database\Eloquent\ModelNotFoundException $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiResponse::error('Resource not found.', [], 404);
            }
        });

        $exceptions->render(function (\Symfony\Component\HttpKernel\Exception\NotFoundHttpException $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiResponse::error('Resource not found.', [], 404);
            }
        });
    })->create();
