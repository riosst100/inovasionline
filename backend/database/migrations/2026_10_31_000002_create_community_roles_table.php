<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Community roles (Admin, Moderator, ...) whose abilities admins set in the dashboard. A region appointment
 * gets one role plus free badge wording ("Kepala Desa <wilayah>"). Chat messages can now be deleted: they
 * stay as a "Pesan ini dihapus" placeholder so replies and the thread keep their shape.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_roles', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('name', 50)->unique();
            $table->json('abilities');
            $table->timestamps();
        });

        $now = now();
        $adminId = (string) Str::ulid();
        DB::table('community_roles')->insert([
            [
                'id' => $adminId,
                'name' => 'Admin',
                'abilities' => json_encode(['delete_posts', 'delete_comments', 'delete_chat_messages']),
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::ulid(),
                'name' => 'Moderator',
                'abilities' => json_encode(['delete_comments', 'delete_chat_messages']),
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);

        Schema::table('region_admins', function (Blueprint $table) {
            $table->ulid('community_role_id')->nullable();
            $table->string('badge_text', 60)->default('Admin <wilayah>');
        });
        // Appointments made before roles existed could already moderate everything.
        DB::table('region_admins')->update(['community_role_id' => $adminId]);
        Schema::table('region_admins', function (Blueprint $table) {
            $table->foreign('community_role_id')->references('id')->on('community_roles')->restrictOnDelete();
        });

        Schema::table('chat_messages', function (Blueprint $table) {
            $table->timestamp('deleted_at')->nullable();
            $table->ulid('deleted_by')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('chat_messages', function (Blueprint $table) {
            $table->dropColumn(['deleted_at', 'deleted_by']);
        });

        Schema::table('region_admins', function (Blueprint $table) {
            $table->dropForeign(['community_role_id']);
            $table->dropColumn(['community_role_id', 'badge_text']);
        });

        Schema::dropIfExists('community_roles');
    }
};
