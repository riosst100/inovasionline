<?php

namespace App\Services;

use App\Models\FlashSaleSlot;
use App\Models\Promotion;
use App\Models\Store;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PromotionService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function create(Store $store, array $data): Promotion
    {
        return DB::transaction(function () use ($store, $data) {
            $productIds = $data['product_ids'];
            $slot = FlashSaleSlot::where('is_active', true)->findOrFail($data['flash_sale_slot_id']);
            $date = $data['date'];

            $startsAt = Carbon::parse("{$date} {$slot->start_time}");
            $endsAt = Carbon::parse("{$date} {$slot->end_time}");

            if ($endsAt->lte($startsAt)) {
                throw new RuntimeException('Invalid flash sale slot time range.');
            }

            if ($startsAt->lt(now())) {
                throw new RuntimeException('Selected flash sale slot has already started or passed for this date.');
            }

            $promotion = $store->promotions()->create([
                'flash_sale_slot_id' => $slot->id,
                'name' => $data['name'],
                'code' => $data['code'] ?? null,
                'type' => $data['type'],
                'discount_value' => $data['discount_value'] ?? null,
                'minimum_purchase' => $data['minimum_purchase'] ?? null,
                'maximum_discount' => $data['maximum_discount'] ?? null,
                'usage_limit' => $data['usage_limit'] ?? null,
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'is_active' => $data['is_active'] ?? true,
            ]);

            $ownedProductIds = $store->products()->whereIn('id', $productIds)->pluck('id');
            $promotion->products()->sync($ownedProductIds);

            return $promotion->load('products.images', 'flashSaleSlot');
        });
    }
}
