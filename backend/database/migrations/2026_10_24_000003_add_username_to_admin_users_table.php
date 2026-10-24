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
        Schema::table('admin_users', function (Blueprint $table) {
            $table->string('username', AdminUser::USERNAME_MAX)->nullable()->after('name');
        });

        // Existing accounts log in with the part of their email before the "@".
        DB::table('admin_users')->orderBy('created_at')->get(['id', 'email'])->each(
            fn ($row) => DB::table('admin_users')->where('id', $row->id)->update([
                'username' => AdminUser::uniqueUsername($row->email),
            ])
        );

        Schema::table('admin_users', function (Blueprint $table) {
            $table->string('username', AdminUser::USERNAME_MAX)->nullable(false)->unique()->change();
        });
    }

    public function down(): void
    {
        Schema::table('admin_users', function (Blueprint $table) {
            $table->dropUnique(['username']);
            $table->dropColumn('username');
        });
    }
};
