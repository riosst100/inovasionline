<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row, app-wide promo badge on the "Belanja Online" tab of the mobile app.
        // Styling is fixed in the app; admin controls text, on/off and the schedule.
        Schema::create('nav_badge_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(false);
            $table->string('label', 16)->default('12.12 Sale');
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->timestamps();
        });

        DB::table('nav_badge_settings')->insert([
            'is_active' => true,
            'label' => '12.12 Sale',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('nav_badge_settings');
    }
};
