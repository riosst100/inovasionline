<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('device_tokens', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->string('user_id', 26)->nullable()->change();
            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('device_tokens', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->dropIndex(['user_id', 'platform']);
        });
        \Illuminate\Support\Facades\DB::table('device_tokens')->whereNull('user_id')->delete();
        Schema::table('device_tokens', function (Blueprint $table) {
            $table->string('user_id', 26)->nullable(false)->change();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'platform']);
        });
    }
};
