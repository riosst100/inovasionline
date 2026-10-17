<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        // Delivery windows buyers pick for IO Same Day. Times are local (Asia/Jakarta).
        Schema::create('delivery_schedules', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('label');
            $table->time('start_time');
            $table->time('end_time');
            // Ordering closes this many minutes before the window starts.
            $table->unsignedInteger('cutoff_minutes')->default(60);
            // Max orders per window per day; null = unlimited.
            $table->unsignedInteger('quota')->nullable();
            // ISO weekdays (1 = Monday … 7 = Sunday); null = every day.
            $table->json('days')->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->ulid('delivery_schedule_id')->nullable()->after('shipping_method_id');
            $table->date('delivery_date')->nullable()->after('delivery_address');
            // Snapshot of the window at checkout, so later schedule edits don't rewrite history.
            $table->json('delivery_slot')->nullable()->after('delivery_date');

            $table->foreign('delivery_schedule_id')->references('id')->on('delivery_schedules')->nullOnDelete();
            $table->index(['delivery_schedule_id', 'delivery_date']);
        });

        // Admins can only toggle shipping methods, so both IO methods have to exist up front.
        $methods = [
            ['type' => 'io_express', 'name' => 'IO Express', 'description' => 'Diantar kurir IO dalam 15-30 menit', 'base_fee' => 15000, 'estimated_delivery_time' => '15-30 menit', 'sort_order' => 0],
            ['type' => 'io_same_day', 'name' => 'IO Same Day', 'description' => 'Diantar hari ini sesuai jadwal yang dipilih', 'base_fee' => 10000, 'estimated_delivery_time' => 'Sesuai jadwal', 'sort_order' => 1],
        ];
        foreach ($methods as $method) {
            if (DB::table('shipping_methods')->where('type', $method['type'])->exists()) {
                continue;
            }
            DB::table('shipping_methods')->insert([
                ...$method,
                'id' => (string) Str::ulid(),
                'rate_type' => 'flat',
                'is_enabled' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $schedules = [
            ['label' => 'Pagi', 'start_time' => '09:00', 'end_time' => '12:00', 'sort_order' => 0],
            ['label' => 'Siang', 'start_time' => '13:00', 'end_time' => '16:00', 'sort_order' => 1],
            ['label' => 'Sore', 'start_time' => '16:00', 'end_time' => '19:00', 'sort_order' => 2],
        ];
        foreach ($schedules as $schedule) {
            DB::table('delivery_schedules')->insert([
                ...$schedule,
                'id' => (string) Str::ulid(),
                'cutoff_minutes' => 60,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropForeign(['delivery_schedule_id']);
            $table->dropIndex(['delivery_schedule_id', 'delivery_date']);
            $table->dropColumn(['delivery_schedule_id', 'delivery_date', 'delivery_slot']);
        });

        Schema::dropIfExists('delivery_schedules');
    }
};
