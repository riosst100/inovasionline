<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ShippingMethodRateResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'shipping_method_id' => $this->shipping_method_id,
            'district_code' => $this->district_code,
            'district_name' => $this->district_name ?? null,
            'village_code' => $this->village_code,
            'village_name' => $this->village_name ?? null,
            'fee' => (float) $this->fee,
            'created_at' => $this->created_at,
        ];
    }
}
