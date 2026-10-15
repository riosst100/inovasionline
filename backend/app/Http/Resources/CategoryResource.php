<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'description' => $this->description,
            'icon' => $this->icon,
            'image_url' => $this->image_path ? (str_starts_with($this->image_path, 'http') ? $this->image_path : asset('storage/'.$this->image_path)) : null,
            'sort_order' => $this->sort_order,
            'is_active' => $this->is_active,
            'created_by' => $this->created_by,
            'products_count' => $this->when(
                array_key_exists('products_count', $this->resource->getAttributes()),
                fn () => (int) $this->products_count,
            ),
        ];
    }
}
