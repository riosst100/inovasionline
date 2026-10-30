<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Tells a buyer's tracking map that the courier moved, over Reverb. Like ChatMessageSent it carries
 * only the order id: the app refetches `GET /orders/{id}/tracking`, which checks ownership and status.
 */
class OrderTrackingUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(public string $orderId) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('order-tracking.'.$this->orderId)];
    }

    public function broadcastAs(): string
    {
        return 'tracking.updated';
    }

    public function broadcastWith(): array
    {
        return ['order_id' => $this->orderId];
    }
}
