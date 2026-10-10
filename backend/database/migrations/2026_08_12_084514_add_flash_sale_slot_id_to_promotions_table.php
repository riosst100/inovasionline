<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('promotions', function (Blueprint $table) {
            $table->ulid('flash_sale_slot_id')->nullable()->after('store_id');
            $table->foreign('flash_sale_slot_id')->references('id')->on('flash_sale_slots')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('promotions', function (Blueprint $table) {
            $table->dropForeign(['flash_sale_slot_id']);
            $table->dropColumn('flash_sale_slot_id');
        });
    }
};
