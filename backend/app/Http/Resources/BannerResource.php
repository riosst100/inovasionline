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
            'image_url' => str_starts_with($this->image_path, 'http') ? $this->image_path : asset('storage/'.$this->image_path),
            'link_url' => $this->link_url,
            'placement' => $this->placement,
            'is_active' => $this->is_active,
            'weekdays' => $this->weekdays ?: null,
            'starts_on' => $this->starts_on?->format('Y-m-d'),
            'ends_on' => $this->ends_on?->format('Y-m-d'),
            'sort_order' => $this->sort_order,
        ];
    }
}
