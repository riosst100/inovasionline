<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravolt\Indonesia\Models\City;

return new class extends Migration
{
    public function up(): void
    {
        // App-wide list of cities the app serves (not per warehouse).
        Schema::create('service_cities', function (Blueprint $table) {
            $table->id();
            $table->char('city_code', 4)->unique();
            $table->timestamps();
        });

        // Keep the previous hardcoded behaviour: all of DKI Jakarta + Kabupaten Brebes.
        $cityTable = (new City)->getTable();
        if (Schema::hasTable($cityTable)) {
            $now = now();
            $rows = DB::table($cityTable)
                ->where('province_code', '31')
                ->orWhere('code', '3329')
                ->pluck('code')
                ->map(fn ($c) => ['city_code' => trim($c), 'created_at' => $now, 'updated_at' => $now])
                ->all();
            if ($rows) {
                DB::table('service_cities')->insert($rows);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('service_cities');
    }
};
