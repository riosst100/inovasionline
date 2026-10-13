<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicBannerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'image_url' => str_starts_with($this->image_path, 'http') ? $this->image_path : asset('storage/'.$this->image_path),
            'link_url' => $this->link_url,
        ];
    }
}
