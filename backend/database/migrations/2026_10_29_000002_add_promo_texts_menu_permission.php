<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /** New menu Tampilan > Tulisan Promosi: roles that handled Banner get it too. */
    public function up(): void
    {
        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = $perms;

            if (in_array('banners.view', $perms, true)) {
                $next[] = 'promo_texts.view';
            }
            if (in_array('banners.manage', $perms, true)) {
                $next[] = 'promo_texts.manage';
            }

            $next = array_values(array_unique($next));
            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update(['permissions' => json_encode($next)]);
            }
        });
    }

    public function down(): void
    {
        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = array_values(array_diff($perms, ['promo_texts.view', 'promo_texts.manage']));

            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update(['permissions' => json_encode($next)]);
            }
        });
    }
};
