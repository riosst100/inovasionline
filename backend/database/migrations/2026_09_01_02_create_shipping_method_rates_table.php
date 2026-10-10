<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipping_method_rates', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('shipping_method_id');
            $table->char('district_code', 7)->nullable();
            $table->char('village_code', 10)->nullable();
            $table->decimal('fee', 12, 2);
            $table->timestamps();

            $table->foreign('shipping_method_id')->references('id')->on('shipping_methods')->cascadeOnDelete();
            $table->index(['shipping_method_id', 'district_code']);
            $table->index(['shipping_method_id', 'village_code']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipping_method_rates');
    }
};
