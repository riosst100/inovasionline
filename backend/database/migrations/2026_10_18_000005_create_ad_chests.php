<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // What a verified view was watched for (AdMob SSV custom_data): the
        // one-time bonus or a step towards the daily reward chest.
        Schema::table('ad_rewards', function (Blueprint $table) {
            $table->string('purpose')->default('bonus');
            $table->index(['user_id', 'purpose', 'created_at']);
        });

        // Single-row, admin-managed config for the "Peti Hadiah" on the home screen.
        Schema::create('ad_chest_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('chests_per_day')->default(5);
            $table->unsignedInteger('daily_budget')->default(100000); // 0 = no cap
            $table->unsignedInteger('step')->default(5);
            $table->json('tiers'); // [{from, to, weight}], weights in % adding up to 100
            $table->timestamps();
        });

        Schema::create('ad_chests', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('user_id');
            $table->unsignedInteger('amount');
            $table->ulid('wallet_transaction_id')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('wallet_transaction_id')->references('id')->on('wallet_transactions')->nullOnDelete();
            $table->index(['user_id', 'created_at']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_chests');
        Schema::dropIfExists('ad_chest_settings');

        Schema::table('ad_rewards', function (Blueprint $table) {
            $table->dropIndex(['user_id', 'purpose', 'created_at']);
            $table->dropColumn('purpose');
        });
    }
};
