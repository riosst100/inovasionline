<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_comments', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('post_id');
            $table->ulid('user_id');
            $table->text('body');
            $table->timestamps();

            $table->index(['post_id', 'created_at']);
            $table->foreign('post_id')->references('id')->on('posts')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('post_comments');
    }
};
