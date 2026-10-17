<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Single store: "seller" wording becomes store/admin wording. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', fn (Blueprint $table) => $table->renameColumn('seller_notes', 'admin_notes'));
        DB::table('shipping_methods')->where('type', 'seller_delivery')->update(['type' => 'store_delivery']);
    }

    public function down(): void
    {
        Schema::table('orders', fn (Blueprint $table) => $table->renameColumn('admin_notes', 'seller_notes'));
        DB::table('shipping_methods')->where('type', 'store_delivery')->update(['type' => 'seller_delivery']);
    }
};
