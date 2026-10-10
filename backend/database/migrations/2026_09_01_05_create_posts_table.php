<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('posts', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->ulid('shared_post_id')->nullable();
            $table->text('body')->nullable();
            $table->timestamps();

            $table->index(['created_at']);
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::table('posts', function (Blueprint $table) {
            $table->foreign('shared_post_id')->references('id')->on('posts')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('posts');
    }
};
