<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('google_id')->nullable()->unique()->after('phone');
        });

        DB::statement('ALTER TABLE users ALTER COLUMN password DROP NOT NULL');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('ALTER TABLE users ALTER COLUMN password SET NOT NULL');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('google_id');
        });
    }
};
