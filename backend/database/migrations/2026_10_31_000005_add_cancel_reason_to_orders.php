<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Who cancelled the order ('admin' / 'buyer' / 'system') and, for admins, the reason shown to the buyer.
        Schema::table('orders', function (Blueprint $table) {
            $table->string('cancelled_by', 10)->nullable()->after('cancelled_at');
            $table->text('cancel_reason')->nullable()->after('cancelled_by');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['cancelled_by', 'cancel_reason']);
        });
    }
};
