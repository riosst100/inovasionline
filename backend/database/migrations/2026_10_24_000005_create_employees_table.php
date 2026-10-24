<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employees', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('name', 150);
            $table->string('phone', 30)->nullable();
            $table->string('position', 100);
            // per_order | monthly | per_delivery; salary_amount is per that unit.
            $table->string('salary_type', 20);
            $table->decimal('salary_amount', 14, 2);
            $table->boolean('is_active')->default(true);
            $table->string('notes')->nullable();
            $table->timestamps();

            $table->index('position');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employees');
    }
};
