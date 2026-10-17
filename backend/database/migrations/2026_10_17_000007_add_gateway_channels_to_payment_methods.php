<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * Midtrans Snap `enabled_payments` codes; one per selectable checkout option.
     * [channel, name, description]
     */
    private const CHANNELS = [
        ['other_qris', 'QRIS', 'Scan QR dengan e-wallet atau m-banking apa pun'],
        ['gopay', 'GoPay', 'Bayar langsung lewat aplikasi Gojek'],
        ['shopeepay', 'ShopeePay', 'Bayar langsung lewat aplikasi Shopee'],
        ['bca_va', 'BCA Virtual Account', 'Transfer ke nomor virtual account BCA'],
        ['bni_va', 'BNI Virtual Account', 'Transfer ke nomor virtual account BNI'],
        ['bri_va', 'BRI Virtual Account', 'Transfer ke nomor virtual account BRI'],
        ['echannel', 'Mandiri Bill Payment', 'Bayar lewat Livin\' by Mandiri atau ATM Mandiri'],
        ['permata_va', 'Permata Virtual Account', 'Transfer ke nomor virtual account Permata'],
        ['credit_card', 'Kartu Kredit/Debit', 'Visa, Mastercard, JCB'],
    ];

    public function up(): void
    {
        Schema::table('payment_methods', function (Blueprint $table) {
            // Null on a payment_gateway method means "let the buyer choose on the Midtrans page".
            $table->string('gateway_channel')->nullable()->after('type');
        });

        // The generic option stays for existing orders and can be re-enabled by an admin.
        DB::table('payment_methods')
            ->where('type', 'payment_gateway')
            ->whereNull('gateway_channel')
            ->update(['is_enabled' => false, 'updated_at' => now()]);

        foreach (self::CHANNELS as $index => [$channel, $name, $description]) {
            if (DB::table('payment_methods')->where('gateway_channel', $channel)->exists()) {
                continue;
            }

            DB::table('payment_methods')->insert([
                'id' => (string) Str::ulid(),
                'type' => 'payment_gateway',
                'gateway_channel' => $channel,
                'name' => $name,
                'description' => $description,
                'is_enabled' => true,
                'sort_order' => $index + 1,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('payment_methods')->whereNotNull('gateway_channel')->delete();
        DB::table('payment_methods')->where('type', 'payment_gateway')->update(['is_enabled' => true]);

        Schema::table('payment_methods', function (Blueprint $table) {
            $table->dropColumn('gateway_channel');
        });
    }
};
