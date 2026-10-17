<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The platform is a single store: drop sellers, seller applications, stores
 * and store members together with their data, remove every store_id, and
 * delete seller accounts. Irreversible — the dropped data cannot be restored.
 */
return new class extends Migration
{
    private const STORE_SCOPED = ['products', 'payment_methods', 'shipping_methods', 'orders', 'promotions'];

    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropUnique(['store_id', 'slug']);
            $table->dropUnique(['store_id', 'sku']);
        });
        Schema::table('promotions', function (Blueprint $table) {
            $table->dropUnique(['store_id', 'code']);
        });
        Schema::table('payment_methods', fn (Blueprint $table) => $table->dropIndex(['store_id', 'is_enabled']));
        Schema::table('shipping_methods', fn (Blueprint $table) => $table->dropIndex(['store_id', 'is_enabled']));
        Schema::table('orders', fn (Blueprint $table) => $table->dropIndex(['store_id', 'status']));

        foreach (self::STORE_SCOPED as $name) {
            Schema::table($name, function (Blueprint $table) {
                $table->dropForeign(['store_id']);
                $table->dropColumn('store_id');
            });
        }

        // Slugs/SKUs/codes were unique per store; with one store they are unique globally.
        Schema::table('products', function (Blueprint $table) {
            $table->unique('slug');
            $table->unique('sku');
        });
        Schema::table('promotions', fn (Blueprint $table) => $table->unique('code'));
        Schema::table('payment_methods', fn (Blueprint $table) => $table->index('is_enabled'));
        Schema::table('shipping_methods', fn (Blueprint $table) => $table->index('is_enabled'));
        Schema::table('orders', fn (Blueprint $table) => $table->index('status'));

        Schema::dropIfExists('store_members');
        Schema::dropIfExists('stores');
        Schema::dropIfExists('sellers');
        Schema::dropIfExists('seller_applications');

        DB::table('users')->whereIn('role', ['seller_owner', 'seller_staff'])->delete();
    }

    public function down(): void
    {
        throw new RuntimeException('Removing multi-seller data is irreversible.');
    }
};
