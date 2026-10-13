<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_users', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('phone')->nullable();
            $table->string('password');
            $table->foreignUlid('role_id')->constrained('roles')->cascadeOnDelete();
            $table->string('avatar_path')->nullable();
            $table->boolean('is_active')->default(true);
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();

            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_users');
    }
};
