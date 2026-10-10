<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photo_purchases', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->ulid('photo_id');
            $table->unsignedInteger('matched_face_index')->default(0);
            $table->decimal('price', 14, 2);
            $table->string('status')->default('paid');
            $table->timestamp('purchased_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('photo_id')->references('id')->on('photos')->cascadeOnDelete();
            $table->unique(['user_id', 'photo_id', 'matched_face_index']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_purchases');
    }
};
