<?php

namespace App\Http\Resources;

use App\Support\Enums\PromotionType;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicProductDetailResource extends JsonResource
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

            'store' => $this->whenLoaded('store', fn () => [
                'id' => $this->store->id,
                'name' => $this->store->name,
                'slug' => $this->store->slug,
                'logo_url' => $this->store->logo_path ? asset('storage/'.$this->store->logo_path) : null,
                'city' => $this->store->city,
                'delivery_available' => $this->store->delivery_available,
                'owner_user_id' => $this->store->seller?->user_id,
            ]),

            'created_at' => $this->created_at,
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
