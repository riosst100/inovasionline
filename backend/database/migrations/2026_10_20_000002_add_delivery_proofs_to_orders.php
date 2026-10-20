<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // Photo + time the driver took the parcel (ready -> on_delivery).
            $table->string('shipped_proof_path')->nullable()->after('completed_at');
            $table->timestamp('shipped_at')->nullable()->after('shipped_proof_path');
            // Photo the driver took at the door (on_delivery -> completed).
            $table->string('delivered_proof_path')->nullable()->after('shipped_at');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['shipped_proof_path', 'shipped_at', 'delivered_proof_path']);
        });
    }
};
