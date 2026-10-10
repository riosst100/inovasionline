<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipping_rate_template_rows', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('shipping_rate_template_id');
            $table->char('district_code', 7)->nullable();
            $table->char('village_code', 10)->nullable();
            $table->decimal('fee', 12, 2);
            $table->timestamps();

            $table->foreign('shipping_rate_template_id')->references('id')->on('shipping_rate_templates')->cascadeOnDelete();
            $table->index(['shipping_rate_template_id', 'district_code']);
            $table->index(['shipping_rate_template_id', 'village_code']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipping_rate_template_rows');
    }
};
