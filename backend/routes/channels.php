<?php

use App\Models\AdminUser;
use App\Models\ChatThread;
use App\Models\User;
use App\Services\ChatService;
use App\Support\Permissions\AdminMenu;
use Illuminate\Support\Facades\Broadcast;

// Admin panel live updates (App\Events\AdminDataChanged): only signals, the data is refetched.
Broadcast::channel('admin.orders', fn ($user) => $user instanceof AdminUser && AdminMenu::canView($user, 'orders'));
Broadcast::channel('admin.dashboard', fn ($user) => $user instanceof AdminUser && AdminMenu::canView($user, 'dashboard'));

Broadcast::channel('chat-thread.{threadId}', function (User $user, string $threadId) {
    $thread = ChatThread::find($threadId);

    if ($thread === null) {
        return false;
    }

    return app(ChatService::class)->canView($user, $thread);
});
