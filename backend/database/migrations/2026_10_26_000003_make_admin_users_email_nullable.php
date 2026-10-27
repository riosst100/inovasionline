<?php

use App\Models\AdminUser;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Couriers are registered and sign in with their phone number; only staff accounts need an email.
        Schema::table('admin_users', function (Blueprint $table) {
            $table->string('email')->nullable()->change();
        });

        // Store existing couriers' phones in the normalized form the phone login looks up.
        DB::table('admin_users')
            ->join('roles', 'roles.id', '=', 'admin_users.role_id')
            ->where('roles.slug', 'driver')
            ->whereNotNull('admin_users.phone')
            ->get(['admin_users.id', 'admin_users.phone'])
            ->each(function ($row) {
                $phone = AdminUser::normalizePhone($row->phone);
                if ($phone !== $row->phone && ! DB::table('admin_users')->where('phone', $phone)->exists()) {
                    DB::table('admin_users')->where('id', $row->id)->update(['phone' => $phone]);
                }
            });
    }

    public function down(): void
    {
        // Couriers created without an email need one before the column can be required again.
        DB::table('admin_users')->whereNull('email')->update([
            'email' => DB::raw("concat(username, '@driver.local')"),
        ]);

        Schema::table('admin_users', function (Blueprint $table) {
            $table->string('email')->nullable(false)->change();
        });
    }
};
