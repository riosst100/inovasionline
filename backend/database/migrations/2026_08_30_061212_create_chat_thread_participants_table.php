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
        Schema::create('chat_thread_participants', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('thread_id');
            $table->ulid('user_id');
            $table->timestamp('joined_at');
            $table->timestamp('last_read_at')->nullable();
            $table->timestamps();

            $table->unique(['thread_id', 'user_id']);
            $table->foreign('thread_id')->references('id')->on('chat_threads')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chat_thread_participants');
    }
};
