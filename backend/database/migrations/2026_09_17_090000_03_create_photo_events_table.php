<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photo_events', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('photographer_id');
            $table->string('title');
            $table->string('slug')->unique();
            $table->date('event_date')->nullable();
            $table->string('cover_photo_path')->nullable();
            $table->string('status')->default('published');
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('photographer_id')->references('id')->on('photographers')->cascadeOnDelete();
            $table->index('photographer_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photo_events');
    }
};
