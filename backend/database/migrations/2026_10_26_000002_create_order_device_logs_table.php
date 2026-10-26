<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Evidence for disputed or fake orders: the device, network and position
     * an order was placed from, frozen at checkout. Written once and never
     * updated, unlike app_installs which follows the install over time.
     */
    public function up(): void
    {
        Schema::create('order_device_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignUlid('order_id')->unique()->constrained()->cascadeOnDelete();
            $table->foreignUlid('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('install_id', 64)->nullable()->index();
            $table->string('device_id', 128)->nullable()->index();
            $table->string('device_name', 120)->nullable();
            $table->string('device_brand', 60)->nullable();
            $table->string('device_model', 120)->nullable();
            $table->string('os_version', 60)->nullable();
            $table->boolean('is_emulator')->nullable();
            $table->json('device_details')->nullable();
            $table->string('app_version', 32)->nullable();
            $table->unsignedInteger('build_number')->nullable();
            $table->string('ip_address', 45)->nullable()->index();
            $table->text('user_agent')->nullable();
            // Last known GPS fix, only when the user already granted location.
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->float('location_accuracy')->nullable();
            $table->timestamp('location_at')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_device_logs');
    }
};
