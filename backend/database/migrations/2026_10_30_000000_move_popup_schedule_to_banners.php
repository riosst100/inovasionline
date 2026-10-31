<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** The popup schedule (weekdays, date range) lives on each popup image, not on the global setting. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            // ISO weekdays 1 (Senin) .. 7 (Minggu); null = every day.
            $table->json('weekdays')->nullable()->after('is_active');
        });

        Schema::table('launch_popup_settings', function (Blueprint $table) {
            $table->dropColumn(['weekdays', 'starts_on', 'ends_on']);
        });
    }

    public function down(): void
    {
        Schema::table('launch_popup_settings', function (Blueprint $table) {
            $table->json('weekdays')->nullable();
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
        });

        Schema::table('banners', function (Blueprint $table) {
            $table->dropColumn('weekdays');
        });
    }
};
