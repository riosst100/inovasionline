<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserVerificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'full_name' => $this->full_name,
            'id_number' => $this->id_number,
            'selfie_url' => asset('storage/'.$this->selfie_path),
            'document_url' => asset('storage/'.$this->document_path),
            'status' => $this->status?->value,
            'rejection_reason' => $this->rejection_reason,
            'reviewed_at' => $this->reviewed_at,
            'created_at' => $this->created_at,
            'user' => $this->whenLoaded('user', fn () => [
                'name' => $this->user->name,
                'email' => $this->user->email,
            ]),
        ];
    }
}
