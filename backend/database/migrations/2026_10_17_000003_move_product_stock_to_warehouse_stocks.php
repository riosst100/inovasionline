<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Stock now lives only in product_warehouse_stocks; products.stock is dropped
 * and a product's stock is the sum over its warehouses. Order items remember
 * which warehouses they were taken from so cancellations can return them.
 */
return new class extends Migration
{
    public function up(): void
    {
        $defaultWarehouse = DB::table('warehouses')->orderByDesc('is_active')->orderBy('code')->value('id');

        // Products that only had the old column get that stock in the default warehouse.
        if ($defaultWarehouse) {
            $now = now();
            DB::table('products')
                ->where('stock', '>', 0)
                ->whereNotExists(fn ($q) => $q->from('product_warehouse_stocks')->whereColumn('product_id', 'products.id'))
                ->orderBy('id')
                ->each(function ($product) use ($defaultWarehouse, $now) {
                    DB::table('product_warehouse_stocks')->insert([
                        'product_id' => $product->id,
                        'warehouse_id' => $defaultWarehouse,
                        'quantity' => $product->stock,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                });
        }

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn('stock');
        });

        Schema::table('order_items', function (Blueprint $table) {
            $table->json('stock_allocations')->nullable()->after('quantity');
        });
    }

    public function down(): void
    {
        Schema::table('order_items', function (Blueprint $table) {
            $table->dropColumn('stock_allocations');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->unsignedInteger('stock')->default(0)->after('sku');
        });

        DB::table('products')->update([
            'stock' => DB::raw('(select coalesce(sum(quantity), 0) from product_warehouse_stocks where product_id = products.id)'),
        ]);
    }
};
