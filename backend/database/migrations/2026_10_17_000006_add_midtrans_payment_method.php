<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        // The order_id sent to Midtrans; differs from order_number when a retry adds a suffix.
        Schema::table('orders', function (Blueprint $table) {
            $table->string('midtrans_order_id')->nullable()->after('payment_expires_at');
        });

        // Admins can only toggle payment methods, so the gateway option has to exist up front.
        if (! DB::table('payment_methods')->where('type', 'payment_gateway')->exists()) {
            DB::table('payment_methods')->insert([
                'id' => (string) Str::ulid(),
                'type' => 'payment_gateway',
                'name' => 'Pembayaran Online',
                'description' => 'QRIS, GoPay, ShopeePay, Virtual Account, kartu kredit (via Midtrans)',
                'is_enabled' => true,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('midtrans_order_id');
        });
    }
};
