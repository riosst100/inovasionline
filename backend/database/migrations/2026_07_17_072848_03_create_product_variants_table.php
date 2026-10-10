<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_variants', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('product_id');
            $table->string('name');
            $table->string('sku')->nullable();
            $table->decimal('price', 14, 2)->nullable();
            $table->unsignedInteger('stock')->default(0);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->unique(['product_id', 'sku']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variants');
    }
};
