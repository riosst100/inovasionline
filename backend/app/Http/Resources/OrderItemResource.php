<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'product_variant_id' => $this->product_variant_id,
            'product_name' => $this->product_name,
            'product_sku' => $this->product_sku,
            'variant_name' => $this->variant_name,
            'product_image_url' => $this->product_image_path ? asset('storage/'.$this->product_image_path) : null,
            'unit_price' => (float) $this->unit_price,
            'quantity' => $this->quantity,
            'discount_amount' => (float) $this->discount_amount,
            'line_total' => (float) $this->line_total,
            'notes' => $this->notes,
        ];
    }
}
