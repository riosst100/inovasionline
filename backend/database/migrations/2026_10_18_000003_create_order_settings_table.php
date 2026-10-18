<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row, app-wide order rules.
        Schema::create('order_settings', function (Blueprint $table) {
            $table->id();
            // How long the buyer may still cancel once the order is being prepared; 0 = not at all.
            $table->unsignedInteger('buyer_cancel_window_seconds')->default(60);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_settings');
    }
};
