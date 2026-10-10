<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promotion_categories', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('promotion_id');
            $table->ulid('category_id');
            $table->timestamps();

            $table->foreign('promotion_id')->references('id')->on('promotions')->cascadeOnDelete();
            $table->foreign('category_id')->references('id')->on('categories')->cascadeOnDelete();
            $table->unique(['promotion_id', 'category_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('promotion_categories');
    }
};
