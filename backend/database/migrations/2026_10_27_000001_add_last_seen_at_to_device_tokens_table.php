<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('device_tokens', function (Blueprint $table) {
            $table->timestamp('last_seen_at')->nullable()->after('platform');
        });

        // Existing rows: the best guess we have is the last time they were written.
        DB::table('device_tokens')->update(['last_seen_at' => DB::raw('updated_at')]);
    }

    public function down(): void
    {
        Schema::table('device_tokens', function (Blueprint $table) {
            $table->dropColumn('last_seen_at');
        });
    }
};
