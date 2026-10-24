<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Keuangan > Pemasukan & Pengeluaran: entries the admin records by hand (operating costs,
        // other income). Paid orders and paid supplier bills are read from their own tables.
        Schema::create('company_transactions', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('type', 10); // income | expense
            $table->string('category', 60);
            $table->decimal('amount', 14, 2);
            $table->date('transaction_date');
            $table->string('description')->nullable();
            $table->foreignUlid('employee_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();

            $table->index(['transaction_date', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('company_transactions');
    }
};
