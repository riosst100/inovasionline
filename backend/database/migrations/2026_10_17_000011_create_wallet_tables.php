<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Closed-loop buyer balance ("Saldo"): topped up through Midtrans, spent at
 * checkout, credited back when a paid order is cancelled. Not withdrawable.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Denormalised for fast reads; wallet_transactions is the source of truth.
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('wallet_balance', 14, 2)->default(0);
        });

        Schema::create('wallet_topups', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('topup_number')->unique();
            $table->ulid('user_id');
            $table->decimal('amount', 14, 2);
            $table->string('status')->default('pending'); // pending | paid | failed | expired
            $table->string('payment_token')->nullable();
            $table->text('payment_redirect_url')->nullable();
            $table->timestamp('payment_expires_at')->nullable();
            $table->string('midtrans_transaction_id')->nullable();
            $table->string('midtrans_payment_type')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'created_at']);
        });

        // Append-only ledger. amount is signed: + credit, - debit.
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->string('type'); // topup | payment | refund | adjustment
            $table->decimal('amount', 14, 2);
            $table->decimal('balance_after', 14, 2);
            $table->string('description');
            $table->ulid('order_id')->nullable();
            $table->ulid('wallet_topup_id')->nullable();
            $table->ulid('admin_user_id')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->nullOnDelete();
            $table->foreign('wallet_topup_id')->references('id')->on('wallet_topups')->nullOnDelete();
            $table->index(['user_id', 'created_at']);
            // One payment and one refund per order, one credit per top-up: guards double-booking.
            $table->unique(['order_id', 'type']);
            $table->unique('wallet_topup_id');
        });

        if (! DB::table('payment_methods')->where('type', 'wallet')->exists()) {
            DB::table('payment_methods')->insert([
                'id' => (string) Str::ulid(),
                'type' => 'wallet',
                'name' => 'Saldo Inovasi',
                'description' => 'Bayar langsung dari saldo akunmu',
                'is_enabled' => true,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('payment_methods')->where('type', 'wallet')->delete();
        Schema::dropIfExists('wallet_transactions');
        Schema::dropIfExists('wallet_topups');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('wallet_balance');
        });
    }
};
