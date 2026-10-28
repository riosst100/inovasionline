<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = $perms;

            if (in_array('payment_gateway.view', $perms, true) || in_array('shipping_methods.view', $perms, true)) {
                $next[] = 'bank_accounts.view';
            }
            if (in_array('payment_gateway.manage', $perms, true) || in_array('shipping_methods.manage', $perms, true)) {
                $next[] = 'bank_accounts.view';
                $next[] = 'bank_accounts.manage';
            }

            $next = array_values(array_unique($next));
            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update([
                    'permissions' => json_encode($next),
                ]);
            }
        });
    }

    public function down(): void
    {
        DB::table('roles')->orderBy('id')->each(function ($role) {
            $perms = json_decode($role->permissions ?? '[]', true) ?: [];
            $next = array_values(array_diff($perms, ['bank_accounts.view', 'bank_accounts.manage']));

            if ($next !== $perms) {
                DB::table('roles')->where('id', $role->id)->update([
                    'permissions' => json_encode($next),
                ]);
            }
        });
    }
};

