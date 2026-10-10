<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payment_methods', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('store_id');
            $table->string('type');
            $table->string('name');
            $table->text('description')->nullable();
            $table->text('instructions')->nullable();
            $table->string('bank_name')->nullable();
            $table->string('account_number')->nullable();
            $table->string('account_holder_name')->nullable();
            $table->boolean('is_enabled')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->index(['store_id', 'is_enabled']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_methods');
    }
};
