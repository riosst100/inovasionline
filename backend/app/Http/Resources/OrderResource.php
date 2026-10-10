<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'store' => $this->whenLoaded('store', fn () => [
                'id' => $this->store->id,
                'name' => $this->store->name,
                'slug' => $this->store->slug,
                'logo_url' => $this->store->logo_path ? asset('storage/'.$this->store->logo_path) : null,
            ]),
            'user' => $this->whenLoaded('user', fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
            ]),
            'payment_method' => $this->whenLoaded('paymentMethod', fn () => $this->paymentMethod ? new PaymentMethodResource($this->paymentMethod) : null),
            'shipping_method' => $this->whenLoaded('shippingMethod', fn () => $this->shippingMethod ? new ShippingMethodResource($this->shippingMethod) : null),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'subtotal' => (float) $this->subtotal,
            'discount_total' => (float) $this->discount_total,
            'shipping_fee' => (float) $this->shipping_fee,
            'tax_total' => (float) $this->tax_total,
            'grand_total' => (float) $this->grand_total,
            'status' => $this->status?->value,
            'payment_status' => $this->payment_status?->value,
            'delivery_method' => $this->delivery_method,
            'delivery_address' => $this->delivery_address,
            'customer_notes' => $this->customer_notes,
            'seller_notes' => $this->seller_notes,
            'status_history' => $this->status_history,
            'accepted_at' => $this->accepted_at,
            'completed_at' => $this->completed_at,
            'cancelled_at' => $this->cancelled_at,
            'created_at' => $this->created_at,
        ];
    }
}
