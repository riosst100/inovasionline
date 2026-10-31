<?php

namespace App\Http\Resources;

use App\Services\PostService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Auth;

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
            'user_verified_badge' => (bool) $this->user?->hasVerifiedBadge(),
            'user_admin_badge' => $this->user?->adminBadgeLabel($this->post->regionCodes()),
            'can_delete' => app(PostService::class)->canDeleteComment(Auth::guard('sanctum')->user(), $this->resource),
            'body' => $this->body,
            'created_at' => $this->created_at,
        ];
    }
}
