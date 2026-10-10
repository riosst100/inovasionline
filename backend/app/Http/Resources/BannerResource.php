<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BannerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'image_url' => asset('storage/'.$this->image_path),
            'link_url' => $this->link_url,
            'is_active' => $this->is_active,
            'sort_order' => $this->sort_order,
        ];
    }
}
