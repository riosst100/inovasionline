<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('search_logs', function (Blueprint $table) {
            $table->string('source', 10)->default('user')->after('search_count');
        });
    }

    public function down(): void
    {
        Schema::table('search_logs', function (Blueprint $table) {
            $table->dropColumn('source');
        });
    }
};
