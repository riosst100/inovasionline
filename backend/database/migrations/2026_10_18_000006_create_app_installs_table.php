<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * One row per customer-app install, kept fresh by the app's heartbeat.
     * Feeds the admin dashboard: installs, active users, who is on checkout.
     */
    public function up(): void
    {
        Schema::create('app_installs', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('install_id', 64)->unique();
            $table->foreignUlid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('platform', 16);
            $table->string('app_version', 32)->nullable();
            $table->string('current_screen', 120)->nullable();
            $table->timestamp('first_seen_at');
            $table->timestamp('last_seen_at')->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_installs');
    }
};
