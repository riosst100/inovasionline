<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('service_fee_settings', function (Blueprint $table) {
            $table->decimal('free_min_subtotal', 12, 2)->nullable()->after('max_fee');
        });
    }

    public function down(): void
    {
        Schema::table('service_fee_settings', function (Blueprint $table) {
            $table->dropColumn('free_min_subtotal');
        });
    }
};
