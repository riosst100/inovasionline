<?php

namespace App\Events;

use App\Support\Enums\ChatThreadType;
use App\Models\ChatMessage;
use App\Models\ChatThread;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Tells chat clients a message was posted, over Reverb. Like AdminDataChanged it carries only ids:
 * clients refetch through the normal permission-checked chat endpoints, so no message body travels
 * over the socket.
 *
 * Channels (routes/channels.php): `chat-thread.{id}` for whoever has that conversation open, plus
 * `user.{id}` for the other side of a direct message so their thread list updates too. Group threads
 * are not fanned out per member (the global thread has everybody in it); their list refreshes on the
 * client's slow fallback poll.
 */
class ChatMessageSent implements ShouldBroadcast, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets;

    public function __construct(
        public string $threadId,
        public string $messageId,
        public ?string $recipientId = null,
    ) {}

    public static function for(ChatThread $thread, ChatMessage $message): self
    {
        $recipientId = null;
        if ($thread->type === ChatThreadType::DM) {
            $recipientId = $thread->user_one_id === $message->sender_id ? $thread->user_two_id : $thread->user_one_id;
        }

        return new self($thread->id, $message->id, $recipientId);
    }

    public function broadcastOn(): array
    {
        $channels = [new PrivateChannel('chat-thread.'.$this->threadId)];
        if ($this->recipientId !== null) {
            $channels[] = new PrivateChannel('user.'.$this->recipientId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'chat.message';
    }

    public function broadcastWith(): array
    {
        return ['thread_id' => $this->threadId, 'message_id' => $this->messageId];
    }
}
