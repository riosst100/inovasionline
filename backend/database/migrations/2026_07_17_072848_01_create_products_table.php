<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('store_id');
            $table->ulid('category_id')->nullable();
            $table->string('name');
            $table->string('slug');
            $table->string('short_description')->nullable();
            $table->longText('description')->nullable();
            $table->string('product_type')->default('physical');

            $table->decimal('regular_price', 14, 2);
            $table->decimal('sale_price', 14, 2)->nullable();
            $table->decimal('cost_price', 14, 2)->nullable();
            $table->boolean('is_taxable')->default(false);

            $table->string('sku')->nullable();
            $table->unsignedInteger('stock')->default(0);
            $table->unsignedInteger('min_stock')->default(0);
            $table->boolean('track_inventory')->default(true);

            $table->decimal('weight', 10, 2)->nullable();
            $table->decimal('length', 10, 2)->nullable();
            $table->decimal('width', 10, 2)->nullable();
            $table->decimal('height', 10, 2)->nullable();
            $table->boolean('requires_shipping')->default(true);

            $table->string('status')->default('draft');
            $table->timestamp('available_start_at')->nullable();
            $table->timestamp('available_end_at')->nullable();

            $table->string('meta_title')->nullable();
            $table->string('meta_description')->nullable();

            $table->unsignedInteger('view_count')->default(0);
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->foreign('category_id')->references('id')->on('categories')->nullOnDelete();
            $table->unique(['store_id', 'slug']);
            $table->unique(['store_id', 'sku']);
            $table->index(['status', 'created_at']);
            $table->index('product_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
