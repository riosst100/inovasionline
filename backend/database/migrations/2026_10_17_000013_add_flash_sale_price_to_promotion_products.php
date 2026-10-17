<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Flash sales now carry a fixed price per product (set by the admin) instead of
 * a slot-wide percentage. Legacy slot-based promotions are converted in place.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('promotion_products', function (Blueprint $table) {
            $table->decimal('flash_sale_price', 14, 2)->nullable()->after('product_id');
        });

        $legacy = DB::table('promotions')
            ->whereNotNull('flash_sale_slot_id')
            ->whereIn('type', ['percentage_discount', 'fixed_discount'])
            ->get();

        foreach ($legacy as $promotion) {
            $rows = DB::table('promotion_products')
                ->join('products', 'products.id', '=', 'promotion_products.product_id')
                ->where('promotion_products.promotion_id', $promotion->id)
                ->get(['promotion_products.id', 'products.regular_price']);

            foreach ($rows as $row) {
                $regular = (float) $row->regular_price;
                $value = (float) $promotion->discount_value;
                $price = $promotion->type === 'percentage_discount'
                    ? $regular - ($regular * $value / 100)
                    : $regular - $value;

                DB::table('promotion_products')->where('id', $row->id)->update(['flash_sale_price' => max(0, round($price))]);
            }

            DB::table('promotions')->where('id', $promotion->id)->update([
                'type' => 'flash_sale',
                'discount_value' => null,
                'flash_sale_slot_id' => null,
            ]);
        }
    }

    public function down(): void
    {
        DB::table('promotions')->where('type', 'flash_sale')->update(['is_active' => false]);

        Schema::table('promotion_products', function (Blueprint $table) {
            $table->dropColumn('flash_sale_price');
        });
    }
};
