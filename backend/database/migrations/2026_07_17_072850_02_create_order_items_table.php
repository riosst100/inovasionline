<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('order_id');
            $table->ulid('product_id')->nullable();
            $table->ulid('product_variant_id')->nullable();

            $table->string('product_name');
            $table->string('product_sku')->nullable();
            $table->string('variant_name')->nullable();
            $table->string('product_image_path')->nullable();

            $table->decimal('unit_price', 14, 2);
            $table->unsignedInteger('quantity');
            $table->decimal('discount_amount', 14, 2)->default(0);
            $table->decimal('line_total', 14, 2);

            $table->text('notes')->nullable();
            $table->timestamps();

            $table->foreign('order_id')->references('id')->on('orders')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->nullOnDelete();
            $table->foreign('product_variant_id')->references('id')->on('product_variants')->nullOnDelete();
            $table->index('order_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
