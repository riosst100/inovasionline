<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostCommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'post_id' => $this->post_id,
            'user_id' => $this->user_id,
            'user_name' => $this->user?->name,
            'user_avatar_url' => $this->user?->avatar_path ? asset('storage/'.$this->user->avatar_path) : null,
            'body' => $this->body,
            'created_at' => $this->created_at,
        ];
    }
}
