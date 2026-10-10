<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('chat_threads', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('type');
            $table->string('region_level')->nullable();
            $table->string('region_code')->nullable();
            $table->ulid('user_one_id')->nullable();
            $table->ulid('user_two_id')->nullable();
            $table->timestamps();

            $table->unique(['type', 'region_code']);
            $table->unique(['user_one_id', 'user_two_id']);
            $table->foreign('user_one_id')->references('id')->on('users')->nullOnDelete();
            $table->foreign('user_two_id')->references('id')->on('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chat_threads');
    }
};
