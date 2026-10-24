<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row: the customer app forces a Google Play update on builds below
        // min_build_number (e.g. after a bug fix); newer releases stay optional.
        Schema::create('app_update_settings', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('min_build_number')->default(0);
            $table->string('message', 255)->nullable();
            $table->timestamps();
        });

        // The app now reports its build number too: the version name stays the
        // same across releases, so only the build tells installs apart.
        Schema::table('app_installs', function (Blueprint $table) {
            $table->unsignedInteger('build_number')->nullable()->after('app_version');
        });
    }

    public function down(): void
    {
        Schema::table('app_installs', function (Blueprint $table) {
            $table->dropColumn('build_number');
        });
        Schema::dropIfExists('app_update_settings');
    }
};
