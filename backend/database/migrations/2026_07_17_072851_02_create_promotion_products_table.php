<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promotion_products', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('promotion_id');
            $table->ulid('product_id');
            $table->timestamps();

            $table->foreign('promotion_id')->references('id')->on('promotions')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->unique(['promotion_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('promotion_products');
    }
};
