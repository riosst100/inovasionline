<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** A courier's latest GPS fix, sent by the driver app while delivering; shown on the buyer's tracking map. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->decimal('last_latitude', 10, 7)->nullable()->after('vehicle_plate_number');
            $table->decimal('last_longitude', 10, 7)->nullable()->after('last_latitude');
            $table->float('last_location_accuracy')->nullable()->after('last_longitude');
            $table->timestamp('last_location_at')->nullable()->after('last_location_accuracy');
        });
    }

    public function down(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->dropColumn(['last_latitude', 'last_longitude', 'last_location_accuracy', 'last_location_at']);
        });
    }
};
