<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Users an admin appointed to look after one region (city / district / village): they get an
 * "Admin <region>" badge and may moderate that region's posts and chat.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('region_admins', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->string('region_level');
            $table->string('region_code', 10);
            // Kept here so badges need no region lookups.
            $table->string('region_name');
            $table->timestamps();

            $table->unique(['user_id', 'region_code']);
            $table->index('region_code');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('region_admins');
    }
};
