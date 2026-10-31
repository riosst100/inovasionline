<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('midtrans_settings', function (Blueprint $table) {
            $table->unsignedSmallInteger('topup_expiry_minutes')->default(5)->after('mode');
        });
    }

    public function down(): void
    {
        Schema::table('midtrans_settings', function (Blueprint $table) {
            $table->dropColumn('topup_expiry_minutes');
        });
    }
};
