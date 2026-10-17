<?php

namespace App\Services;

use App\Support\Enums\PromotionType;
use Illuminate\Support\Facades\DB;

/**
 * Resolves flash sale prices for products that are in a running flash sale.
 * Bound as scoped, so the lookup runs once per request/job.
 */
class FlashSalePricing
{
    /** @var array<string, float>|null */
    private ?array $prices = null;

    public function priceFor(string $productId): ?float
    {
        return $this->activePrices()[$productId] ?? null;
    }

    /**
     * @return array<string, float> product_id => lowest running flash sale price
     */
    public function activePrices(): array
    {
        if ($this->prices !== null) {
            return $this->prices;
        }

        $now = now();

        return $this->prices = DB::table('promotion_products')
            ->join('promotions', 'promotions.id', '=', 'promotion_products.promotion_id')
            ->where('promotions.type', PromotionType::FLASH_SALE->value)
            ->where('promotions.is_active', true)
            ->whereNull('promotions.deleted_at')
            ->where('promotions.starts_at', '<=', $now)
            ->where('promotions.ends_at', '>=', $now)
            ->whereNotNull('promotion_products.flash_sale_price')
            ->groupBy('promotion_products.product_id')
            ->selectRaw('promotion_products.product_id, MIN(promotion_products.flash_sale_price) as price')
            ->pluck('price', 'product_id')
            ->map(fn ($price) => (float) $price)
            ->all();
    }
}
