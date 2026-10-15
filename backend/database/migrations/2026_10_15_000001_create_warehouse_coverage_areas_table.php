<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A row covers one village, or a whole district when village_code is null.
        // Many warehouses may cover the same area, so there is no unique constraint across warehouses.
        Schema::create('warehouse_coverage_areas', function (Blueprint $table) {
            $table->id();
            $table->ulid('warehouse_id');
            $table->char('district_code', 7);
            $table->char('village_code', 10)->nullable();
            $table->timestamps();

            $table->foreign('warehouse_id')->references('id')->on('warehouses')->cascadeOnDelete();
            $table->index('district_code');
            $table->index('village_code');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warehouse_coverage_areas');
    }
};
