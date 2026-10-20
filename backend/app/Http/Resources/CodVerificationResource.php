<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class CodVerificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'video_url' => Storage::disk('public')->url($this->video_path),
            'steps' => $this->steps ?? [],
            'device' => $this->device,
            'ip_address' => $this->ip_address,
            'status' => $this->status,
            'revoked_reason' => $this->revoked_reason,
            'revoked_at' => $this->revoked_at,
            'created_at' => $this->created_at,
            'user' => $this->whenLoaded('user', fn () => $this->user ? [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'email' => $this->user->email,
                'phone' => $this->user->phone,
            ] : null),
        ];
    }
}
