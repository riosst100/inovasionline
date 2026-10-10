<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('store_members', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('store_id');
            $table->ulid('user_id');
            $table->string('role')->default('staff');
            $table->json('permissions')->nullable();
            $table->timestamps();

            $table->foreign('store_id')->references('id')->on('stores')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['store_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('store_members');
    }
};
