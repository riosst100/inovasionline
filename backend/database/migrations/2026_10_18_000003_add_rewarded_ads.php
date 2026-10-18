<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admob_settings', function (Blueprint $table) {
            $table->boolean('home_bottom_banner')->default(true);
            $table->boolean('product_list_banner')->default(true);
            $table->string('android_rewarded_id')->nullable();
            $table->string('ios_rewarded_id')->nullable();
            // The one-time saldo bonus can only be claimed after a fully watched rewarded ad.
            $table->boolean('bonus_requires_ad')->default(false);
        });

        // Rewarded-ad views confirmed by AdMob's server-side verification callback.
        // transaction_id is AdMob's own id, so a retried callback is stored once;
        // a bonus claim consumes one unused view.
        Schema::create('ad_rewards', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->string('transaction_id')->unique();
            $table->string('ad_unit');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'consumed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_rewards');

        Schema::table('admob_settings', function (Blueprint $table) {
            $table->dropColumn([
                'home_bottom_banner', 'product_list_banner',
                'android_rewarded_id', 'ios_rewarded_id', 'bonus_requires_ad',
            ]);
        });
    }
};
