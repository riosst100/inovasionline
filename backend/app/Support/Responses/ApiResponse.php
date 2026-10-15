<?php

namespace App\Support\Responses;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Pagination\LengthAwarePaginator;

class ApiResponse
{
    public static function success(mixed $data = null, string $message = 'Success.', array $meta = [], int $status = 200): JsonResponse
    {
        $payload = [
            'success' => true,
            'message' => $message,
            'data' => $data,
        ];

        if (! empty($meta)) {
            $payload['meta'] = $meta;
        }

        return response()->json($payload, $status);
    }

    /**
     * @param  class-string<JsonResource>  $resourceClass
     */
    public static function paginated(LengthAwarePaginator $paginator, string $resourceClass, string $message = 'Success.'): JsonResponse
    {
        return self::success(
            $resourceClass::collection($paginator->items()),
            $message,
            [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    /**
     * 403 response the mobile app recognises (via `code`) to lock itself down.
     */
    public static function blocked(\App\Models\User $user): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Akun Anda telah diblokir.',
            'code' => 'ACCOUNT_BLOCKED',
            'data' => [
                'block_reason' => $user->block_reason,
                'contact_url' => config('services.support.contact_url'),
            ],
        ], 403);
    }

    /**
     * 403 response for a feature-level ban (chat / posts / purchase).
     */
    public static function banned(\App\Models\User $user, string $feature): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Anda dibatasi untuk menggunakan fitur ini.',
            'code' => 'FEATURE_BANNED',
            'data' => [
                'feature' => $feature,
                'ban_reason' => $user->ban_reason,
                'contact_url' => config('services.support.contact_url'),
            ],
        ], 403);
    }

    public static function error(string $message = 'An error occurred.', array $errors = [], int $status = 400): JsonResponse
    {
        $payload = [
            'success' => false,
            'message' => $message,
        ];

        if (! empty($errors)) {
            $payload['errors'] = $errors;
        }

        return response()->json($payload, $status);
    }
}
