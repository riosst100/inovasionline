<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ChatParticipantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->user->id,
            'name' => $this->user->name,
            'avatar_url' => $this->user->avatar_path ? asset('storage/'.$this->user->avatar_path) : null,
            'is_seller' => $this->user->isSeller(),
        ];
    }
}
