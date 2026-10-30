<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Narrows a served city (service_cities) down to some districts or
        // villages. A city without rows here is served as a whole.
        Schema::create('service_areas', function (Blueprint $table) {
            $table->id();
            $table->string('level', 10); // district | village
            $table->string('code', 10);
            $table->char('city_code', 4)->index();
            $table->string('district_code', 10);
            $table->timestamps();

            $table->unique(['level', 'code']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_areas');
    }
};
