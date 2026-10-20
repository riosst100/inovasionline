<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Delivery addresses a buyer saved, so checkout offers them to pick from
     * instead of typing the address again.
     */
    public function up(): void
    {
        Schema::create('user_addresses', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignUlid('user_id')->constrained()->cascadeOnDelete();
            $table->string('label', 50)->nullable();
            $table->string('recipient_name');
            $table->string('recipient_phone', 30);
            $table->char('province_code', 2);
            $table->char('city_code', 4);
            $table->char('district_code', 7);
            $table->char('village_code', 10);
            $table->string('address_detail', 500);
            // Bumped when the address is added or used for an order; the most
            // recent one is offered first at checkout.
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'last_used_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_addresses');
    }
};
