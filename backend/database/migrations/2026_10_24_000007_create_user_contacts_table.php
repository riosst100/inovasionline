<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Phone contacts uploaded by the customer app, one row per number per
     * install. Rows are keyed by install_id so a guest can share contacts
     * before signing in; user_id is filled in once that install logs in.
     * Feeds post, chat and product suggestions (match `phone` against
     * users.phone).
     */
    public function up(): void
    {
        Schema::create('user_contacts', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('install_id', 64);
            $table->foreignUlid('user_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('name')->nullable();
            $table->string('phone', 20)->index();
            $table->timestamps();

            $table->unique(['install_id', 'phone']);
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_contacts');
    }
};
