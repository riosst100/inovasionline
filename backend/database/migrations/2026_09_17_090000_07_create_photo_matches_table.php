<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photo_matches', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->ulid('photo_id');
            $table->decimal('confidence_score', 5, 4);
            $table->unsignedInteger('matched_face_index')->default(0);
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('photo_id')->references('id')->on('photos')->cascadeOnDelete();
            $table->unique(['user_id', 'photo_id', 'matched_face_index']);
            $table->index('user_id');
            $table->index('photo_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_matches');
    }
};
