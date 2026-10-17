<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Admins can add their own shipping methods (e.g. "Jastip Maysa"), each with its
 * own delivery schedules, so "needs a schedule" becomes a per-method flag instead
 * of being implied by the io_same_day type.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipping_methods', function (Blueprint $table) {
            $table->boolean('requires_schedule')->default(false)->after('estimated_delivery_time');
            // How far ahead buyers can book: today plus (n - 1) days.
            $table->unsignedSmallInteger('schedule_days_ahead')->default(3)->after('requires_schedule');
        });
        DB::table('shipping_methods')->where('type', 'io_same_day')->update(['requires_schedule' => true]);

        Schema::table('delivery_schedules', function (Blueprint $table) {
            $table->ulid('shipping_method_id')->nullable()->after('id');
        });

        // Existing windows were all IO Same Day's.
        $sameDayId = DB::table('shipping_methods')->where('type', 'io_same_day')->value('id');
        if ($sameDayId) {
            DB::table('delivery_schedules')->update(['shipping_method_id' => $sameDayId]);
        } else {
            DB::table('delivery_schedules')->delete();
        }

        Schema::table('delivery_schedules', function (Blueprint $table) {
            $table->ulid('shipping_method_id')->nullable(false)->change();
            $table->foreign('shipping_method_id')->references('id')->on('shipping_methods')->cascadeOnDelete();
            $table->index(['shipping_method_id', 'is_active']);
        });

        // Dates with no deliveries; shipping_method_id null = every method.
        Schema::create('delivery_holidays', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('shipping_method_id')->nullable();
            $table->date('date');
            $table->string('name');
            $table->timestamps();

            $table->foreign('shipping_method_id')->references('id')->on('shipping_methods')->cascadeOnDelete();
            $table->unique(['shipping_method_id', 'date']);
            $table->index('date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_holidays');

        Schema::table('delivery_schedules', function (Blueprint $table) {
            $table->dropForeign(['shipping_method_id']);
            $table->dropIndex(['shipping_method_id', 'is_active']);
            $table->dropColumn('shipping_method_id');
        });

        Schema::table('shipping_methods', function (Blueprint $table) {
            $table->dropColumn(['requires_schedule', 'schedule_days_ahead']);
        });
    }
};
