<?php

namespace App\Services;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\MessageTarget;
use Kreait\Firebase\Messaging\MulticastSendReport;
use Kreait\Firebase\Messaging\Notification as FirebaseNotification;

class NotificationService
{
    public function __construct(private readonly Messaging $messaging) {}

    /**
     * Send a push notification to every device registered to a user.
     * Tokens that Firebase reports as no longer valid are removed.
     *
     * @param  array<string, mixed>  $data
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = $user->deviceTokens()->pluck('token');

        if ($tokens->isEmpty()) {
            return;
        }

        $this->sendToTokens($tokens->all(), $title, $body, $data);
    }

    /**
     * @param  array<int, string>  $tokens
     * @param  array<string, mixed>  $data
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): void
    {
        if ($tokens === []) {
            return;
        }

        $message = CloudMessage::new()
            ->withNotification(FirebaseNotification::create($title, $body))
            ->withData(array_map('strval', $data));

        $report = $this->messaging->sendMulticast($message, $tokens);

        $this->pruneInvalidTokens($report);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function sendToTopic(string $topic, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::withTarget(MessageTarget::TOPIC, $topic)
            ->withNotification(FirebaseNotification::create($title, $body))
            ->withData(array_map('strval', $data));

        try {
            $this->messaging->send($message);
        } catch (\Throwable $e) {
            Log::warning('Failed to send FCM topic notification.', [
                'topic' => $topic,
                'error' => $e->getMessage(),
            ]);
        }
    }

    private function pruneInvalidTokens(MulticastSendReport $report): void
    {
        $invalidTokens = $report->invalidTokens();

        if ($invalidTokens === []) {
            return;
        }

        DeviceToken::query()->whereIn('token', $invalidTokens)->delete();
    }
}
