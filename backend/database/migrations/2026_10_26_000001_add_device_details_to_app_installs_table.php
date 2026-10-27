<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Device facts the app reports on launch, kept for security (spotting one
     * phone behind many accounts, emulators). device_id is the Android ID /
     * iOS identifierForVendor, which survives an app reinstall unlike
     * install_id. IP addresses are taken from the request, not from the app.
     */
    public function up(): void
    {
        Schema::table('app_installs', function (Blueprint $table) {
            $table->string('device_id', 128)->nullable()->index()->after('install_id');
            $table->string('device_name', 120)->nullable()->after('device_id');
            $table->string('device_brand', 60)->nullable()->after('device_name');
            $table->string('device_model', 120)->nullable()->after('device_brand');
            $table->string('os_version', 60)->nullable()->after('device_model');
            $table->boolean('is_emulator')->nullable()->after('os_version');
            $table->json('device_details')->nullable()->after('is_emulator');
            $table->string('first_ip_address', 45)->nullable()->after('device_details');
            $table->string('ip_address', 45)->nullable()->index()->after('first_ip_address');
        });
    }

    public function down(): void
    {
        Schema::table('app_installs', function (Blueprint $table) {
            $table->dropColumn([
                'device_id', 'device_name', 'device_brand', 'device_model', 'os_version',
                'is_emulator', 'device_details', 'first_ip_address', 'ip_address',
            ]);
        });
    }
};
