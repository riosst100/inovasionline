<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PhotographerApplicationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'business_name' => $this->business_name,
            'portfolio_url' => $this->portfolio_url,
            'status' => $this->status?->value,
            'rejection_reason' => $this->rejection_reason,
            'created_at' => $this->created_at,
        ];
    }
}
