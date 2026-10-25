<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Instant orders (no delivery schedule) must be shipped within this many minutes of being
        // placed; the admin panel counts down to it and alerts when it is close or passed.
        Schema::table('order_settings', function (Blueprint $table) {
            $table->unsignedSmallInteger('instant_dispatch_minutes')->default(30);
        });
    }

    public function down(): void
    {
        Schema::table('order_settings', function (Blueprint $table) {
            $table->dropColumn('instant_dispatch_minutes');
        });
    }
};
