<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The user's single face-verification status. cod_verifications stays the event log;
 * verification_id points at the event that set the status (verified by it, or revoked on it).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('verification_status', 20)->nullable();
            $table->foreignUlid('verification_id')->nullable()->constrained('cod_verifications')->nullOnDelete();
        });

        // Backfill from each user's latest event.
        DB::statement(<<<'SQL'
            update users set verification_status = latest.status, verification_id = latest.id
            from (
                select distinct on (user_id) id, user_id, status
                from cod_verifications
                order by user_id, created_at desc, id desc
            ) latest
            where latest.user_id = users.id
        SQL);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('verification_id');
            $table->dropColumn('verification_status');
        });
    }
};
