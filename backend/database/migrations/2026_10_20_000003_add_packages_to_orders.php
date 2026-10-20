<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // How the admin split the order into parcels: [[{order_item_id, quantity}, ...], ...].
            // Null means the default single parcel holding every item.
            $table->json('packages')->nullable()->after('delivered_proof_path');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('packages');
        });
    }
};
