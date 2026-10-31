<?php

namespace App\Http\Resources;

use App\Services\ChatService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Auth;

class ChatMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $deleted = $this->deleted_at !== null;

        return [
            'id' => $this->id,
            'thread_id' => $this->thread_id,
            'sender_id' => $this->sender_id,
            'sender_name' => $this->sender?->name,
            'is_official' => $this->sender_id === null,
            'sender_verified_badge' => (bool) $this->sender?->hasVerifiedBadge(),
            'sender_admin_badge' => $this->sender?->adminBadgeLabel(array_filter([$this->thread?->region_code])),
            // Deleted: the text is gone, the app shows "Pesan ini dihapus".
            'is_deleted' => $deleted,
            'body' => $deleted ? '' : $this->body,
            'can_delete' => app(ChatService::class)->canDeleteMessage(Auth::guard('sanctum')->user(), $this->resource),
            'reply_to' => $this->whenLoaded('replyTo', fn () => $this->replyTo ? [
                'id' => $this->replyTo->id,
                'sender_id' => $this->replyTo->sender_id,
                'sender_name' => $this->replyTo->sender_id === null ? 'Inovasi Online' : $this->replyTo->sender?->name,
                'body' => $this->replyTo->deleted_at !== null ? 'Pesan ini dihapus' : $this->replyTo->body,
            ] : null),
            'created_at' => $this->created_at,
        ];
    }
}
