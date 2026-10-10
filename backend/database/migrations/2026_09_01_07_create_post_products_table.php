<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_products', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('post_id');
            $table->ulid('product_id');
            $table->timestamps();

            $table->unique(['post_id', 'product_id']);
            $table->foreign('post_id')->references('id')->on('posts')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('post_products');
    }
};
