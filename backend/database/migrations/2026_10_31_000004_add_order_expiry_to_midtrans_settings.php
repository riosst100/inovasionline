<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('midtrans_settings', function (Blueprint $table) {
            $table->unsignedSmallInteger('order_expiry_minutes')->default(5)->after('topup_expiry_minutes');
        });
    }

    public function down(): void
    {
        Schema::table('midtrans_settings', function (Blueprint $table) {
            $table->dropColumn('order_expiry_minutes');
        });
    }
};
