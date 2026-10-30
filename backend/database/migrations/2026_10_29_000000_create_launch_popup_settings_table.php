<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('launch_popup_settings', function (Blueprint $table) {
            $table->id();
            // off | admob | image
            $table->string('mode', 16)->default('off');
            // ISO weekdays 1 (Senin) .. 7 (Minggu); null = every day.
            $table->json('weekdays')->nullable();
            $table->unsignedTinyInteger('max_per_day')->default(1);
            $table->date('starts_on')->nullable();
            $table->date('ends_on')->nullable();
            $table->timestamps();
        });

        Schema::table('banners', function (Blueprint $table) {
            $table->date('starts_on')->nullable()->after('is_active');
            $table->date('ends_on')->nullable()->after('starts_on');
        });
    }

    public function down(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            $table->dropColumn(['starts_on', 'ends_on']);
        });
        Schema::dropIfExists('launch_popup_settings');
    }
};
