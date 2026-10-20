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
        Schema::create('cod_verifications', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignUlid('user_id')->constrained()->cascadeOnDelete();
            $table->string('video_path');
            // Liveness steps the app reports as completed, e.g. ["come_closer","turn_right",...].
            $table->json('steps')->nullable();
            $table->string('device')->nullable();
            $table->string('ip_address', 45)->nullable();
            // verified: counts for checkout. revoked: an admin reviewed the recording and withdrew it.
            $table->string('status')->default('verified');
            $table->text('revoked_reason')->nullable();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });

        if (! DB::table('payment_methods')->where('type', 'cash_on_delivery')->exists()) {
            DB::table('payment_methods')->insert([
                'id' => (string) Str::ulid(),
                'type' => 'cash_on_delivery',
                'name' => 'Bayar di Tempat (COD)',
                'description' => 'Bayar tunai ke kurir saat pesanan tiba. Perlu verifikasi wajah satu kali.',
                'instructions' => 'Siapkan uang pas saat kurir tiba.',
                'is_enabled' => true,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('payment_methods')->where('type', 'cash_on_delivery')->delete();
        Schema::dropIfExists('cod_verifications');
    }
};
