<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SellerApplicationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'store_name' => $this->store_name,
            'store_slug' => $this->store_slug,
            'business_type' => $this->business_type,
            'main_category_id' => $this->main_category_id,
            'business_description' => $this->business_description,
            'address' => $this->address,
            'province' => $this->province,
            'city' => $this->city,
            'district' => $this->district,
            'postal_code' => $this->postal_code,
            'status' => $this->status?->value,
            'rejection_reason' => $this->rejection_reason,
            'created_at' => $this->created_at,
        ];
    }
}
