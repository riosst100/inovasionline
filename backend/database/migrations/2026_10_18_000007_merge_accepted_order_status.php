<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * The "accepted" (Diterima) status is gone: orders go pending -> processing -> ready -> completed.
     * Any order still sitting in accepted moves on to processing.
     */
    public function up(): void
    {
        DB::table('orders')->where('status', 'accepted')->update(['status' => 'processing']);
    }

    public function down(): void
    {
        // Irreversible: the merged rows are indistinguishable from real processing orders.
    }
};
