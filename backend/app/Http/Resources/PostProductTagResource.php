<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostProductTagResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'regular_price' => $this->regular_price,
            'sale_price' => $this->sale_price,
            'image_url' => $this->images->first() ? asset('storage/'.$this->images->first()->path) : null,
            'store_slug' => $this->store?->slug,
            'store_name' => $this->store?->name,
        ];
    }
}
