<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// PostgreSQL does not index foreign keys on its own. These columns are joined/filtered on hot paths
// (category pages, feed, chat, cart, checkout address pickers) and had no index.
return new class extends Migration
{
    /** @var array<string, list<string|list<string>>> */
    private array $indexes = [
        'products' => ['category_id', ['status', 'category_id']],
        'categories' => ['parent_id'],
        'cart_items' => ['product_id', 'product_variant_id'],
        'order_items' => ['product_id', 'product_variant_id'],
        'orders' => ['payment_method_id', 'shipping_method_id', ['payment_status', 'created_at']],
        'posts' => ['user_id'],
        'post_media' => ['post_id'],
        'post_likes' => ['user_id'],
        'post_comments' => ['user_id'],
        'post_products' => ['product_id'],
        'chat_messages' => ['sender_id'],
        'chat_thread_participants' => ['user_id'],
        'chat_threads' => ['user_two_id'],
        'product_warehouse_stocks' => ['warehouse_id'],
        'promotion_products' => ['product_id'],
        'promotion_categories' => ['category_id'],
        'indonesia_cities' => ['province_code'],
        'indonesia_districts' => ['city_code'],
        'indonesia_villages' => ['district_code'],
    ];

    public function up(): void
    {
        foreach ($this->indexes as $table => $definitions) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            foreach ($definitions as $columns) {
                $columns = (array) $columns;
                if (! Schema::hasColumns($table, $columns) || Schema::hasIndex($table, $columns)) {
                    continue;
                }
                Schema::table($table, fn (Blueprint $blueprint) => $blueprint->index($columns));
            }
        }
    }

    public function down(): void
    {
        foreach ($this->indexes as $table => $definitions) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            foreach ($definitions as $columns) {
                $columns = (array) $columns;
                if (Schema::hasColumns($table, $columns) && Schema::hasIndex($table, $columns)) {
                    Schema::table($table, fn (Blueprint $blueprint) => $blueprint->dropIndex($columns));
                }
            }
        }
    }
};
