<?php

use App\Models\ChatThread;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('chat-thread.{threadId}', function (User $user, string $threadId) {
    $thread = ChatThread::find($threadId);

    if ($thread === null) {
        return false;
    }

    return app(ChatService::class)->canView($user, $thread);
});
