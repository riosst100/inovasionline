<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('photos', function (Blueprint $table) {
            // Array of {embedding: float[512], bbox: float[4]} per detected
            // face, since one event photo can contain multiple people.
            $table->json('embeddings')->nullable()->after('watermarked_path');
        });
    }

    public function down(): void
    {
        Schema::table('photos', function (Blueprint $table) {
            $table->dropColumn('embeddings');
        });
    }
};
