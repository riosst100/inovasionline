<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Texts shown as a slider strip on the app home screen (Promosi > Gratis Ongkir).
        Schema::table('free_shipping_settings', function (Blueprint $table) {
            $table->json('promo_texts')->nullable()->after('shipping_method_ids');
        });

        DB::table('free_shipping_settings')->update([
            'promo_texts' => json_encode(['Gratis Ongkir untuk pembayaran pakai Saldo Belanja']),
        ]);
    }

    public function down(): void
    {
        Schema::table('free_shipping_settings', function (Blueprint $table) {
            $table->dropColumn('promo_texts');
        });
    }
};
