<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\BroadcastNotificationRequest;
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
}
