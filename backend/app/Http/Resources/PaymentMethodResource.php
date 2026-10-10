<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentMethodResource extends JsonResource
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
            'name' => $this->name,
            'description' => $this->description,
            'instructions' => $this->instructions,
            'bank_name' => $this->bank_name,
            'account_number' => $this->account_number,
            'account_holder_name' => $this->account_holder_name,
            'is_enabled' => $this->is_enabled,
            'sort_order' => $this->sort_order,
            'created_at' => $this->created_at,
        ];
    }
}
