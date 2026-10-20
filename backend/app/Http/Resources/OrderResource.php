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
            'user' => $this->whenLoaded('user', fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
            ]),
            'payment_method' => $this->whenLoaded('paymentMethod', fn () => $this->paymentMethod ? new PaymentMethodResource($this->paymentMethod) : null),
            'shipping_method' => $this->whenLoaded('shippingMethod', fn () => $this->shippingMethod ? new ShippingMethodResource($this->shippingMethod) : null),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'items_count' => $this->whenCounted('items'),
            'subtotal' => (float) $this->subtotal,
            'discount_total' => (float) $this->discount_total,
            'shipping_fee' => (float) $this->shipping_fee,
            'service_fee' => (float) $this->service_fee,
            'tax_total' => (float) $this->tax_total,
            'grand_total' => (float) $this->grand_total,
            'status' => $this->status?->value,
            'payment_status' => $this->payment_status?->value,
            'payment_token' => $this->payment_token,
            'payment_redirect_url' => $this->payment_redirect_url,
            'payment_expires_at' => $this->payment_expires_at,
            'paid_at' => $this->paid_at,
            'delivery_method' => $this->delivery_method,
            'delivery_address' => $this->delivery_address,
            'delivery_date' => $this->delivery_date?->toDateString(),
            'delivery_slot' => $this->delivery_slot,
            'customer_notes' => $this->customer_notes,
            'admin_notes' => $this->admin_notes,
            'status_history' => $this->status_history,
            'accepted_at' => $this->accepted_at,
            'completed_at' => $this->completed_at,
            'cancelled_at' => $this->cancelled_at,
            'qr_code' => $this->qrCode(),
            'packages_count' => $this->packagesCount(),
            // One QR per parcel; the driver may scan any of them.
            'packages' => $this->whenLoaded('items', fn () => collect($this->packingList())
                ->map(fn (array $items, int $i) => [
                    'number' => $i + 1,
                    'qr_code' => $this->packageQrCode($i + 1),
                    'items' => $items,
                ])->all()),
            'shipped_at' => $this->shipped_at,
            'shipped_proof_url' => $this->shipped_proof_path ? asset('storage/'.$this->shipped_proof_path) : null,
            'delivered_proof_url' => $this->delivered_proof_path ? asset('storage/'.$this->delivered_proof_path) : null,
            'can_cancel' => $this->buyerCanCancel(),
            'cancel_on_hold' => $this->isCancelOnHold(),
            // Relative (and frozen while on hold), so the app's countdown ignores the device clock.
            'cancel_seconds_left' => $this->buyerCancelSecondsLeft(),
            'created_at' => $this->created_at,
        ];
    }
}
