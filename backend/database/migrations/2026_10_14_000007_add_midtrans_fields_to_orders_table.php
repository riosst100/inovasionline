<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('payment_token')->nullable()->after('payment_status');
            $table->text('payment_redirect_url')->nullable()->after('payment_token');
            $table->timestamp('payment_expires_at')->nullable()->after('payment_redirect_url');
            $table->string('midtrans_transaction_id')->nullable()->after('payment_expires_at');
            $table->string('midtrans_payment_type')->nullable()->after('midtrans_transaction_id');
            $table->timestamp('paid_at')->nullable()->after('midtrans_payment_type');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'payment_token',
                'payment_redirect_url',
                'payment_expires_at',
                'midtrans_transaction_id',
                'midtrans_payment_type',
                'paid_at',
            ]);
        });
    }
};
