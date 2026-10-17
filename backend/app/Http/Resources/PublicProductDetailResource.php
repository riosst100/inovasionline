<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\ResolvesPromotionPrice;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicProductDetailResource extends JsonResource
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
            'short_description' => $this->short_description,
            'description' => $this->description,
            'product_type' => $this->product_type?->value,

            'regular_price' => $this->regular_price,
            'sale_price' => $salePrice !== null ? number_format($salePrice, 2, '.', '') : null,
            'discount_percent' => $discountPercent,
            'promotion_ends_at' => $promotion?->ends_at,

            'stock' => $this->stock,
            'sold_count' => (int) ($this->order_items_sum_quantity ?? 0),

            'weight' => $this->weight,
            'requires_shipping' => $this->requires_shipping,

            'images' => ProductImageResource::collection($this->whenLoaded('images')),

            'variants' => $this->whenLoaded('variants', fn () => $this->variants
                ->where('is_active', true)
                ->values()
                ->map(fn ($variant) => [
                    'id' => $variant->id,
                    'name' => $variant->name,
                    'price' => (float) $variant->price,
                    'stock' => $variant->stock,
                ])),

            'category' => $this->whenLoaded('category', fn () => [
                'id' => $this->category->id,
                'name' => $this->category->name,
                'slug' => $this->category->slug,
            ]),

            'created_at' => $this->created_at,
        ];
    }
}
