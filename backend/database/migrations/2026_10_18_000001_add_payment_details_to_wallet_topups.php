<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Latest Midtrans status payload (VA number, bank, QRIS issuer, …) for the admin top-up detail. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wallet_topups', function (Blueprint $table) {
            $table->jsonb('payment_details')->nullable();
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::table('wallet_topups', function (Blueprint $table) {
            $table->dropIndex(['status', 'created_at']);
            $table->dropColumn('payment_details');
        });
    }
};
