<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Where a banner shows in the app: the home hero slider, or the image popup shown once a day on
     * opening the app. Existing banners stay in the slider.
     */
    public function up(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            $table->string('placement', 20)->default('slider')->after('link_url')->index();
        });
    }

    public function down(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            $table->dropIndex(['placement']);
            $table->dropColumn('placement');
        });
    }
};
