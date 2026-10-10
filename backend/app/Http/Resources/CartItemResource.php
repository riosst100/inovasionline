<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CartItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $variant = $this->variant;
        $product = $this->product;

        $unitPrice = $variant?->price ?? $product->sale_price ?? $product->regular_price;
        $stock = $variant?->stock ?? $product->stock;

        return [
            'id' => $this->id,
            'product_id' => $product->id,
            'product_name' => $product->name,
            'product_slug' => $product->slug,
            'product_image_url' => $product->images->first() ? asset('storage/'.$product->images->first()->path) : null,
            'variant_id' => $variant?->id,
            'variant_name' => $variant?->name,
            'unit_price' => (float) $unitPrice,
            'stock' => (int) $stock,
            'quantity' => $this->quantity,
            'line_total' => (float) $unitPrice * $this->quantity,
        ];
    }
}
