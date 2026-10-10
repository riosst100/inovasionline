<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Auth;

class PostResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $viewer = Auth::guard('sanctum')->user();

        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'user_name' => $this->user?->name,
            'user_avatar_url' => $this->user?->avatar_path ? asset('storage/'.$this->user->avatar_path) : null,
            'body' => $this->body,
            'media' => $this->media->map(fn ($media) => [
                'id' => $media->id,
                'type' => $media->type->value,
                'url' => asset('storage/'.$media->path),
                'thumbnail_url' => $media->thumbnail_path ? asset('storage/'.$media->thumbnail_path) : null,
                'duration_seconds' => $media->duration_seconds,
            ]),
            'products' => PostProductTagResource::collection($this->whenLoaded('products')),
            'shared_post' => $this->when($this->shared_post_id !== null, fn () => $this->sharedPost ? new self($this->sharedPost) : null),
            'like_count' => (int) ($this->likes_count ?? 0),
            'comment_count' => (int) ($this->comments_count ?? 0),
            'share_count' => (int) ($this->shares_count ?? 0),
            'is_liked' => $viewer ? $this->likes->isNotEmpty() : false,
            'is_mine' => $viewer ? $this->user_id === $viewer->id : false,
            'created_at' => $this->created_at,
        ];
    }
}
