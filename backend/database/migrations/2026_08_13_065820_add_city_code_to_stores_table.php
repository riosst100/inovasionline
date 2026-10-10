<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $citiesTable = Schema::hasTable('indonesia_cities') ? 'indonesia_cities' : 'cities';

        Schema::table('stores', function (Blueprint $table) use ($citiesTable) {
            $table->char('city_code', 4)->nullable()->after('city');
            $table->foreign('city_code')->references('code')->on($citiesTable)->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropForeign(['city_code']);
            $table->dropColumn('city_code');
        });
    }
};
