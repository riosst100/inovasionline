<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row, admin-managed rule for Promosi > Gratis Ongkir.
        Schema::create('free_shipping_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(false);
            $table->decimal('min_subtotal', 12, 2)->nullable();
            $table->json('payment_method_ids'); // payment methods that qualify
            $table->json('shipping_method_ids'); // shipping methods that qualify
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('free_shipping_settings');
    }
};
