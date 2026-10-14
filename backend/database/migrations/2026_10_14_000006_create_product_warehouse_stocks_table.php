<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_warehouse_stocks', function (Blueprint $table) {
            $table->ulid('product_id');
            $table->ulid('warehouse_id');
            $table->unsignedInteger('quantity')->default(0);
            $table->timestamps();

            $table->primary(['product_id', 'warehouse_id']);
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->foreign('warehouse_id')->references('id')->on('warehouses')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_warehouse_stocks');
    }
};
