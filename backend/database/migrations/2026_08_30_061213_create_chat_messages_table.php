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
        Schema::create('chat_messages', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('thread_id');
            $table->ulid('sender_id')->nullable();
            $table->text('body');
            $table->timestamps();

            $table->index(['thread_id', 'created_at']);
            $table->foreign('thread_id')->references('id')->on('chat_threads')->cascadeOnDelete();
            $table->foreign('sender_id')->references('id')->on('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('chat_messages');
    }
};
