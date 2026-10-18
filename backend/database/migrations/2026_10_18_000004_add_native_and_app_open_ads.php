<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admob_settings', function (Blueprint $table) {
            $table->string('android_native_id')->nullable();
            $table->string('ios_native_id')->nullable();
            // A native ad after every Nth post in the Posts feed; 0 = none.
            $table->unsignedSmallInteger('posts_native_every')->default(6);
        });
    }

    public function down(): void
    {
        Schema::table('admob_settings', function (Blueprint $table) {
            $table->dropColumn([
                'android_native_id', 'ios_native_id', 'posts_native_every',
            ]);
        });
    }
};
