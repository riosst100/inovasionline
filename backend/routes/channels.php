<?php

use App\Models\AdminUser;
use App\Models\ChatThread;
use App\Models\Order;
use App\Models\User;
use App\Services\ChatService;
use App\Support\Permissions\AdminMenu;
use Illuminate\Support\Facades\Broadcast;

// Admin panel live updates (App\Events\AdminDataChanged): only signals, the data is refetched.
Broadcast::channel('admin.orders', fn ($user) => $user instanceof AdminUser && AdminMenu::canView($user, 'orders'));
Broadcast::channel('admin.dashboard', fn ($user) => $user instanceof AdminUser && AdminMenu::canView($user, 'dashboard'));

// A user's own channel: signals that one of their direct-message threads changed.
Broadcast::channel('user.{userId}', fn ($user, string $userId) => $user instanceof User && (string) $user->id === $userId);

// The buyer's tracking map (App\Events\OrderTrackingUpdated): signals that the courier moved.
Broadcast::channel('order-tracking.{orderId}', fn ($user, string $orderId) => $user instanceof User
    && Order::whereKey($orderId)->where('user_id', $user->id)->exists());

Broadcast::channel('chat-thread.{threadId}', function (User $user, string $threadId) {
    $thread = ChatThread::find($threadId);

    if ($thread === null) {
        return false;
    }

    return app(ChatService::class)->canView($user, $thread);
});
