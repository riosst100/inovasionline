<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipping_methods', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('store_id');
            $table->string('type');
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('base_fee', 12, 2)->default(0);
            $table->decimal('fee_per_km', 12, 2)->nullable();
            $table->decimal('min_order_amount', 14, 2)->nullable();
            $table->decimal('max_distance_km', 8, 2)->nullable();
            $table->string('estimated_delivery_time')->nullable();

            $table->string('pickup_address')->nullable();
            $table->text('pickup_instructions')->nullable();
            $table->json('pickup_hours')->nullable();

            $table->decimal('delivery_radius_km', 8, 2)->nullable();
            $table->decimal('free_shipping_min_amount', 14, 2)->nullable();

            $table->boolean('is_enabled')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->index(['store_id', 'is_enabled']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipping_methods');
    }
};
