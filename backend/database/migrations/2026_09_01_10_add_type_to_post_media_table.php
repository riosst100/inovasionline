<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('post_media', function (Blueprint $table) {
            $table->string('type')->default('image')->after('post_id');
            $table->string('thumbnail_path')->nullable()->after('path');
            $table->unsignedInteger('duration_seconds')->nullable()->after('thumbnail_path');
        });
    }

    public function down(): void
    {
        Schema::table('post_media', function (Blueprint $table) {
            $table->dropColumn(['type', 'thumbnail_path', 'duration_seconds']);
        });
    }
};
