<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PromotionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'flash_sale_slot' => $this->whenLoaded('flashSaleSlot', fn () => $this->flashSaleSlot ? new FlashSaleSlotResource($this->flashSaleSlot) : null),
            'name' => $this->name,
            'code' => $this->code,
            'type' => $this->type?->value,
            'discount_value' => $this->discount_value,
            'minimum_purchase' => $this->minimum_purchase,
            'maximum_discount' => $this->maximum_discount,
            'usage_limit' => $this->usage_limit,
            'usage_count' => $this->usage_count,
            'starts_at' => $this->starts_at,
            'ends_at' => $this->ends_at,
            'is_active' => $this->is_active,
            'is_currently_active' => $this->isCurrentlyActive(),
            'products' => ProductResource::collection($this->whenLoaded('products')),
            'created_at' => $this->created_at,
        ];
    }
}
