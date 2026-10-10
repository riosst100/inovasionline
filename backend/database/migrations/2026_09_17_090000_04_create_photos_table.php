<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photos', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('photographer_id');
            $table->ulid('photo_event_id')->nullable();
            $table->string('path');
            $table->string('watermarked_path')->nullable();
            $table->decimal('price', 14, 2)->default(0);
            $table->string('status')->default('processing');
            $table->unsignedInteger('face_count')->default(0);
            $table->timestamp('taken_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('photographer_id')->references('id')->on('photographers')->cascadeOnDelete();
            $table->foreign('photo_event_id')->references('id')->on('photo_events')->nullOnDelete();
            $table->index('photographer_id');
            $table->index('status');
            $table->index('photo_event_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photos');
    }
};
