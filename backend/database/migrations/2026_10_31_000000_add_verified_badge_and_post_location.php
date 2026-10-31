<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Verified badge (set by an admin) marks a user's posts as "Resmi" in the app; every post also keeps
 * the author's region at posting time so the "Publik" feed can be filtered by location.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('verified_badge_at')->nullable();
        });

        Schema::table('posts', function (Blueprint $table) {
            $table->char('province_code', 2)->nullable();
            $table->char('city_code', 4)->nullable();
            $table->char('district_code', 7)->nullable();
            $table->char('village_code', 10)->nullable();

            $table->index(['province_code', 'created_at']);
            $table->index(['city_code', 'created_at']);
            $table->index(['district_code', 'created_at']);
            $table->index(['village_code', 'created_at']);
        });

        foreach (['province_code', 'city_code', 'district_code', 'village_code'] as $column) {
            DB::statement("update posts set {$column} = (select users.{$column} from users where users.id = posts.user_id)");
        }
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->dropIndex(['province_code', 'created_at']);
            $table->dropIndex(['city_code', 'created_at']);
            $table->dropIndex(['district_code', 'created_at']);
            $table->dropIndex(['village_code', 'created_at']);
            $table->dropColumn(['province_code', 'city_code', 'district_code', 'village_code']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('verified_badge_at');
        });
    }
};
