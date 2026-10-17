<?php

namespace App\Http\Resources\Concerns;

use App\Models\Promotion;
use App\Support\Enums\PromotionType;

/**
 * Picks the cheapest price among the product's loaded promotions.
 * Flash sales use their per-product price; other promotions discount the regular price.
 */
trait ResolvesPromotionPrice
{
    /**
     * @return array{0: float|null, 1: Promotion|null} [sale price, promotion it came from]
     */
    private function resolvePromotionPrice(float $regularPrice): array
    {
        $best = null;
        $bestPromotion = null;

        $promotions = $this->relationLoaded('promotions') ? $this->promotions : collect();

        foreach ($promotions as $promotion) {
            $price = $this->promotionPrice($regularPrice, $promotion);

            if ($price !== null && ($best === null || $price < $best)) {
                $best = $price;
                $bestPromotion = $promotion;
            }
        }

        if ($best === null) {
            return [$this->sale_price !== null ? (float) $this->sale_price : null, null];
        }

        return [$best, $bestPromotion];
    }

    private function promotionPrice(float $regularPrice, Promotion $promotion): ?float
    {
        $discountValue = (float) $promotion->discount_value;

        $price = match ($promotion->type) {
            PromotionType::FLASH_SALE => $promotion->pivot?->flash_sale_price !== null
                ? (float) $promotion->pivot->flash_sale_price
                : null,
            PromotionType::PERCENTAGE_DISCOUNT => $regularPrice - ($regularPrice * $discountValue / 100),
            PromotionType::FIXED_DISCOUNT => $regularPrice - $discountValue,
            default => null,
        };

        return $price === null ? null : max(0, $price);
    }
}
