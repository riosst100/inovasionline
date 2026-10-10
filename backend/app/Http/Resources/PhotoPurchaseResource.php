<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PhotoPurchaseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'photo' => new PhotoResource($this->whenLoaded('photo')),
            'price' => (float) $this->price,
            'status' => $this->status?->value,
            'purchased_at' => $this->purchased_at,
        ];
    }
}
