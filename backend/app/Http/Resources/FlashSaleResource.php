<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FlashSaleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $now = now();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'starts_at' => $this->starts_at,
            'ends_at' => $this->ends_at,
            'is_active' => $this->is_active,
            'status' => match (true) {
                ! $this->is_active => 'inactive',
                $now->lt($this->starts_at) => 'upcoming',
                $now->gt($this->ends_at) => 'ended',
                default => 'running',
            },
            'products_count' => $this->whenCounted('products'),
            'products' => $this->whenLoaded('products', fn () => $this->products->map(fn ($product) => [
                'product_id' => $product->id,
                'name' => $product->name,
                'sku' => $product->sku,
                'image_url' => $product->images->first()
                    ? (str_starts_with($product->images->first()->path, 'http') ? $product->images->first()->path : asset('storage/'.$product->images->first()->path))
                    : null,
                'regular_price' => (float) $product->regular_price,
                'sale_price' => $product->sale_price !== null ? (float) $product->sale_price : null,
                'flash_sale_price' => $product->pivot->flash_sale_price !== null ? (float) $product->pivot->flash_sale_price : null,
            ])->values()),
            'created_at' => $this->created_at,
        ];
    }
}
