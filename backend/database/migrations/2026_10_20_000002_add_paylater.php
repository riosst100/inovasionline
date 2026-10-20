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
        Schema::table('order_settings', function (Blueprint $table) {
            // Completed orders a customer needs before Paylater unlocks.
            $table->unsignedInteger('paylater_min_transactions')->default(3);
            // Days the customer has to settle a Paylater order.
            $table->unsignedInteger('paylater_due_days')->default(7);
        });

        if (! DB::table('payment_methods')->where('type', 'paylater')->exists()) {
            DB::table('payment_methods')->insert([
                'id' => (string) Str::ulid(),
                'type' => 'paylater',
                'name' => 'Paylater',
                'description' => 'Belanja dulu, bayar nanti. Perlu verifikasi wajah satu kali.',
                'instructions' => 'Lunasi tagihan sebelum jatuh tempo.',
                'is_enabled' => true,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('payment_methods')->where('type', 'paylater')->delete();

        Schema::table('order_settings', function (Blueprint $table) {
            $table->dropColumn(['paylater_min_transactions', 'paylater_due_days']);
        });
    }
};
