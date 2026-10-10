<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('photographers', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id')->unique();
            $table->ulid('photographer_application_id')->nullable();
            $table->string('status')->default('approved');
            $table->string('display_name');
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('photographer_application_id')->references('id')->on('photographer_applications')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photographers');
    }
};
