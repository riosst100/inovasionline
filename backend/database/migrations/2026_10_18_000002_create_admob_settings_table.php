<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row, app-wide AdMob config for the mobile app. The AdMob *App ID* is
        // baked into the native build (AndroidManifest / Info.plist); only ad unit IDs
        // and placements live here so they can change without a release.
        Schema::create('admob_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(false);
            $table->string('android_banner_id')->nullable();
            $table->string('ios_banner_id')->nullable();
            $table->string('android_interstitial_id')->nullable();
            $table->string('ios_interstitial_id')->nullable();
            $table->boolean('home_banner')->default(true);
            $table->boolean('product_detail_banner')->default(true);
            $table->boolean('interstitial_enabled')->default(false);
            // Show an interstitial on every Nth product detail opened.
            $table->unsignedSmallInteger('interstitial_every')->default(5);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admob_settings');
    }
};
