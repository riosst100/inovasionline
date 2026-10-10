<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ShippingMethodResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'store' => $this->whenLoaded('store', fn () => [
                'id' => $this->store->id,
                'name' => $this->store->name,
                'slug' => $this->store->slug,
            ]),
            'type' => $this->type?->value,
            'rate_type' => $this->rate_type?->value,
            'name' => $this->name,
            'description' => $this->description,
            'base_fee' => (float) $this->base_fee,
            'resolved_fee' => $this->when(isset($this->resolved_fee), fn () => (float) $this->resolved_fee),
            'min_order_amount' => $this->min_order_amount !== null ? (float) $this->min_order_amount : null,
            'estimated_delivery_time' => $this->estimated_delivery_time,
            'pickup_address' => $this->pickup_address,
            'pickup_instructions' => $this->pickup_instructions,
            'pickup_hours' => $this->pickup_hours,
            'delivery_radius_km' => $this->delivery_radius_km !== null ? (float) $this->delivery_radius_km : null,
            'free_shipping_min_amount' => $this->free_shipping_min_amount !== null ? (float) $this->free_shipping_min_amount : null,
            'is_enabled' => $this->is_enabled,
            'sort_order' => $this->sort_order,
            'created_at' => $this->created_at,
        ];
    }
}
