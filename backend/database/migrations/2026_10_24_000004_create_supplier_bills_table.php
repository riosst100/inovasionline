<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Keuangan > Tagihan Supplier: what the platform owes its suppliers.
        Schema::create('supplier_bills', function (Blueprint $table) {
            $table->ulid('id')->primary();
            // Bills are financial records: a supplier with bills can't be deleted.
            $table->foreignUlid('supplier_id')->constrained()->restrictOnDelete();
            $table->string('bill_number', 60);
            $table->date('bill_date');
            $table->date('due_date')->nullable();
            $table->decimal('amount', 14, 2);
            $table->string('notes')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->string('payment_notes')->nullable();
            $table->timestamps();

            $table->unique(['supplier_id', 'bill_number']);
            $table->index(['paid_at', 'due_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('supplier_bills');
    }
};
