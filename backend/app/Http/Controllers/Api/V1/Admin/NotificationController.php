<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\BroadcastNotificationRequest;
use App\Http\Requests\Admin\SendNotificationRequest;
use App\Models\DeviceToken;
use App\Services\NotificationService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    public const BROADCAST_TOPIC = 'all_users';

    public function __construct(private readonly NotificationService $notificationService) {}

    public function broadcast(BroadcastNotificationRequest $request): JsonResponse
    {
        $this->notificationService->sendToTopic(
            self::BROADCAST_TOPIC,
            $request->validated('title'),
            $request->validated('body'),
            ['type' => 'promo']
        );

        return ApiResponse::success(null, 'Broadcast notification sent.');
    }

    /**
     * Manual push from the admin panel: to every device (topic) or to the chosen customers.
     */
    public function send(SendNotificationRequest $request): JsonResponse
    {
        $title = $request->validated('title');
        $body = $request->validated('body');
        $data = ['type' => 'promo'];

        if ($request->validated('target') === 'all') {
            $this->notificationService->sendToTopic(self::BROADCAST_TOPIC, $title, $body, $data);

            return ApiResponse::success(null, 'Notifikasi dikirim ke semua pengguna.');
        }

        $userIds = $request->validated('user_ids');
        $tokens = DeviceToken::query()->whereIn('user_id', $userIds)->pluck('token', 'user_id');

        if ($tokens->isEmpty()) {
            return ApiResponse::error('Pengguna yang dipilih belum punya perangkat terdaftar untuk menerima notifikasi.', [], 422);
        }

        $this->notificationService->sendToTokens($tokens->values()->all(), $title, $body, $data);

        return ApiResponse::success([
            'users' => $tokens->keys()->count(),
            'users_without_device' => count($userIds) - $tokens->keys()->count(),
        ], 'Notifikasi dikirim.');
    }
}
