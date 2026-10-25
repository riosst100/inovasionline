<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Support\Facades\Cache;

/**
 * Tells open admin panels that data behind the dashboard / order alerts changed, over Reverb.
 * Carries only the topic: clients refetch through the permission-checked endpoints, so nothing a
 * role may not see is pushed. Sent by model listeners in AppServiceProvider.
 *
 * Channels (routes/channels.php): `admin.dashboard` gets every topic, `admin.orders` only orders.
 */
class AdminDataChanged implements ShouldBroadcast, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets;

    public const ORDERS = 'orders';

    public const DASHBOARD = 'dashboard';

    public function __construct(public string $topic) {}

    /**
     * At most one signal per topic per second, so a bulk import doesn't flood the socket; clients
     * refetch once more shortly after a signal to catch changes made inside that second.
     */
    public static function signal(string $topic): void
    {
        if (Cache::add("admin-data-changed:{$topic}", true, 1)) {
            event(new self($topic));
        }
    }

    public function broadcastOn(): array
    {
        $channels = [new PrivateChannel('admin.dashboard')];
        if ($this->topic === self::ORDERS) {
            $channels[] = new PrivateChannel('admin.orders');
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'admin.changed';
    }

    public function broadcastWith(): array
    {
        return ['topic' => $this->topic];
    }
}
