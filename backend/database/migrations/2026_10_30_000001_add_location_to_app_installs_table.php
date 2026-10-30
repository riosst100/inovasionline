<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Last known position (only when the user already granted location
     * permission; the app never prompts for it) and the HTTP user agent, so
     * the admin can see everything about a guest install.
     */
    public function up(): void
    {
        Schema::table('app_installs', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('ip_address');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->float('location_accuracy')->nullable()->after('longitude');
            $table->timestamp('location_at')->nullable()->after('location_accuracy');
            $table->string('user_agent', 500)->nullable()->after('location_at');
        });
    }

    public function down(): void
    {
        Schema::table('app_installs', function (Blueprint $table) {
            $table->dropColumn(['latitude', 'longitude', 'location_accuracy', 'location_at', 'user_agent']);
        });
    }
};
