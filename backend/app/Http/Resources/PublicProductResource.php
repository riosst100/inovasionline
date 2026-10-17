<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\ResolvesPromotionPrice;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicProductResource extends JsonResource
{
    use ResolvesPromotionPrice;

    public function toArray(Request $request): array
    {
        $regularPrice = (float) $this->regular_price;
        [$salePrice, $promotion] = $this->resolvePromotionPrice($regularPrice);

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
            'image_url' => $this->images->first() ? (str_starts_with($this->images->first()->path, 'http') ? $this->images->first()->path : asset('storage/'.$this->images->first()->path)) : null,
            'promotion_ends_at' => $promotion?->ends_at,
        ];
    }
}
