<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('promotions', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('store_id');
            $table->string('name');
            $table->string('code')->nullable();
            $table->string('type');
            $table->decimal('discount_value', 14, 2)->nullable();
            $table->decimal('minimum_purchase', 14, 2)->nullable();
            $table->decimal('maximum_discount', 14, 2)->nullable();
            $table->unsignedInteger('usage_limit')->nullable();
            $table->unsignedInteger('usage_count')->default(0);
            $table->string('banner_path')->nullable();
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->unique(['store_id', 'code']);
            $table->index(['is_active', 'starts_at', 'ends_at']);
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->foreign('promotion_id')->references('id')->on('promotions')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropForeign(['promotion_id']);
        });

        Schema::dropIfExists('promotions');
    }
};
