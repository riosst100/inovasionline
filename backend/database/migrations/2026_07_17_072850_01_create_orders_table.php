<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('order_number')->unique();
            $table->ulid('store_id');
            $table->ulid('user_id');
            $table->ulid('payment_method_id')->nullable();
            $table->ulid('shipping_method_id')->nullable();
            $table->ulid('promotion_id')->nullable();

            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('discount_total', 14, 2)->default(0);
            $table->decimal('shipping_fee', 14, 2)->default(0);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->decimal('grand_total', 14, 2)->default(0);

            $table->string('status')->default('pending');
            $table->string('payment_status')->default('unpaid');

            $table->string('delivery_method')->nullable();
            $table->json('delivery_address')->nullable();

            $table->text('customer_notes')->nullable();
            $table->text('seller_notes')->nullable();
            $table->json('status_history')->nullable();

            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('payment_method_id')->references('id')->on('payment_methods')->nullOnDelete();
            $table->foreign('shipping_method_id')->references('id')->on('shipping_methods')->nullOnDelete();

            $table->index(['store_id', 'status']);
            $table->index(['user_id', 'status']);
            $table->index('payment_status');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
