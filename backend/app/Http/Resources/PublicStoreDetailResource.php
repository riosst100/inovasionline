<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicStoreDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'description' => $this->description,
            'logo_url' => $this->logo_path ? asset('storage/'.$this->logo_path) : null,
            'cover_url' => $this->cover_path ? asset('storage/'.$this->cover_path) : null,
            'address' => $this->address,
            'city' => $this->city,
            'province' => $this->province,
            'is_featured' => (bool) $this->is_featured,
            'delivery_available' => (bool) $this->delivery_available,
            'product_count' => (int) ($this->products_count ?? 0),
            'sold_count' => (int) ($this->order_items_sum_quantity ?? 0),
            'owner_user_id' => $this->whenLoaded('seller', fn () => $this->seller?->user_id),
        ];
    }
}
