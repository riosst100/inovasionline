<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->string('vehicle_type')->nullable()->after('phone');
            $table->string('vehicle_plate_number')->nullable()->after('vehicle_type');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->ulid('driver_id')->nullable()->after('user_id')->index();
            $table->foreign('driver_id')->references('id')->on('admin_users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropForeign(['driver_id']);
            $table->dropColumn('driver_id');
        });

        Schema::table('admin_users', function (Blueprint $table) {
            $table->dropColumn(['vehicle_type', 'vehicle_plate_number']);
        });
    }
};
