<?php

namespace App\Http\Resources;

use App\Support\Enums\PromotionType;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $regularPrice = (float) $this->regular_price;
        $promotion = $this->relationLoaded('promotions') ? $this->promotions->first() : null;

        $salePrice = $promotion
            ? $this->computeSalePrice($regularPrice, $promotion)
            : ($this->sale_price !== null ? (float) $this->sale_price : null);

        $discountPercent = $salePrice !== null && $regularPrice > 0
            ? (int) round((($regularPrice - $salePrice) / $regularPrice) * 100)
            : null;

        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'regular_price' => $this->regular_price,
            'sale_price' => $salePrice !== null ? number_format($salePrice, 2, '.', '') : null,
            'discount_percent' => $discountPercent,
            'stock' => $this->stock,
            'sold_count' => (int) ($this->order_items_sum_quantity ?? 0),
            'image_url' => $this->images->first() ? asset('storage/'.$this->images->first()->path) : null,
            'store_name' => $this->store?->name,
            'promotion_ends_at' => $promotion?->ends_at,
        ];
    }

    private function computeSalePrice(float $regularPrice, mixed $promotion): float
    {
        $discountValue = (float) $promotion->discount_value;

        $salePrice = $promotion->type === PromotionType::PERCENTAGE_DISCOUNT
            ? $regularPrice - ($regularPrice * $discountValue / 100)
            : $regularPrice - $discountValue;

        return max(0, $salePrice);
    }
}
