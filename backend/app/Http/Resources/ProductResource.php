<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'short_description' => $this->short_description,
            'description' => $this->description,
            'product_type' => $this->product_type?->value,

            'regular_price' => $this->regular_price,
            'sale_price' => $this->sale_price,
            'cost_price' => $this->cost_price,
            'is_taxable' => $this->is_taxable,

            'sku' => $this->sku,
            'stock' => $this->stock,
            'min_stock' => $this->min_stock,
            'track_inventory' => $this->track_inventory,

            'weight' => $this->weight,
            'length' => $this->length,
            'width' => $this->width,
            'height' => $this->height,
            'requires_shipping' => $this->requires_shipping,

            'status' => $this->status?->value,
            'available_start_at' => $this->available_start_at,
            'available_end_at' => $this->available_end_at,

            'meta_title' => $this->meta_title,
            'meta_description' => $this->meta_description,

            'images' => ProductImageResource::collection($this->whenLoaded('images')),

            'created_at' => $this->created_at,
        ];
    }
}
