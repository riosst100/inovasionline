<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FlashSaleScheduleSlotResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource['slot']->id,
            'label' => $this->resource['slot']->label,
            'start_time' => substr((string) $this->resource['slot']->start_time, 0, 5),
            'end_time' => substr((string) $this->resource['slot']->end_time, 0, 5),
            'starts_at' => $this->resource['starts_at'],
            'ends_at' => $this->resource['ends_at'],
            'status' => $this->resource['status'],
            'products' => PublicProductResource::collection($this->resource['products']),
        ];
    }
}
