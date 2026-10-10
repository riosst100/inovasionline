<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_face_profiles', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id')->unique();
            $table->string('selfie_path');
            $table->json('embedding')->nullable();
            $table->string('status')->default('pending');
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_face_profiles');
    }
};
