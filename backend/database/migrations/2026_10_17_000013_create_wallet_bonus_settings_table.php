<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row, admin-managed config for the one-time "saldo belanja" bonus.
        Schema::create('wallet_bonus_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('step')->default(500);
            $table->json('tiers'); // [{from, to, weight}], weights in % adding up to 100
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_bonus_settings');
    }
};
