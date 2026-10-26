<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row Midtrans configuration managed from the admin panel. Keys are kept per
        // mode so switching sandbox <-> production does not lose the other pair.
        Schema::create('midtrans_settings', function (Blueprint $table) {
            $table->id();
            $table->string('mode', 10)->default('sandbox'); // sandbox | production
            $table->text('sandbox_server_key')->nullable(); // encrypted
            $table->string('sandbox_client_key')->nullable();
            $table->text('production_server_key')->nullable(); // encrypted
            $table->string('production_client_key')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('midtrans_settings');
    }
};
