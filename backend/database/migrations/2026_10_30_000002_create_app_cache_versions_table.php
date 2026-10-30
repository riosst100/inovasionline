<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One version number per group of data the mobile app caches on the phone.
        Schema::create('app_cache_versions', function (Blueprint $table) {
            $table->string('group_key', 40)->primary();
            $table->unsignedBigInteger('version')->default(1);
            $table->timestamps();
        });

        // New menu Pengaturan > Cache Aplikasi: roles that handle Update Aplikasi get it too.
        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = $perms;

            if (in_array('app_update.view', $perms, true)) {
                $next[] = 'app_cache.view';
            }
            if (in_array('app_update.manage', $perms, true)) {
                $next[] = 'app_cache.manage';
            }

            $next = array_values(array_unique($next));
            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update(['permissions' => json_encode($next)]);
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_cache_versions');

        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = array_values(array_diff($perms, ['app_cache.view', 'app_cache.manage']));

            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update(['permissions' => json_encode($next)]);
            }
        });
    }
};
