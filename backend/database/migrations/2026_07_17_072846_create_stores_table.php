<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stores', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('seller_id');
            $table->ulid('category_id')->nullable();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->string('business_type');
            $table->string('logo_path')->nullable();
            $table->string('cover_path')->nullable();
            $table->string('phone')->nullable();
            $table->string('whatsapp')->nullable();
            $table->string('email')->nullable();
            $table->string('website')->nullable();
            $table->string('address')->nullable();
            $table->string('province')->nullable();
            $table->string('city')->nullable();
            $table->string('district')->nullable();
            $table->string('postal_code')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->json('operating_hours')->nullable();
            $table->json('social_links')->nullable();
            $table->string('status')->default('open');
            $table->boolean('delivery_available')->default(false);
            $table->boolean('is_featured')->default(false);
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('seller_id')->references('id')->on('sellers')->cascadeOnDelete();
            $table->foreign('category_id')->references('id')->on('categories')->nullOnDelete();
            $table->index(['status', 'is_featured']);
            $table->index('business_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stores');
    }
};
