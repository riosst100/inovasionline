<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The buyer's cancel window freezes while they read the cancel confirmation;
        // backing out of it closes the window for good.
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('cancel_hold_started_at')->nullable()->after('cancelled_at');
            $table->timestamp('cancel_declined_at')->nullable()->after('cancel_hold_started_at');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['cancel_hold_started_at', 'cancel_declined_at']);
        });
    }
};
