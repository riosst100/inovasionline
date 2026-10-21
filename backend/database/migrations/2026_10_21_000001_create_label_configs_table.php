<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('label_configs', function (Blueprint $table) {
            $table->id();
            $table->string('group', 40);
            $table->string('key', 60);
            $table->string('label');
            $table->string('color', 20)->default('slate');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['group', 'key']);
        });

        $rows = [
            ['order_status', 'pending', 'Belum Bayar', 'amber'],
            ['order_status', 'processing', 'Perlu Diproses', 'violet'],
            ['order_status', 'ready', 'Perlu Dikirim', 'emerald'],
            ['order_status', 'on_delivery', 'Sedang Dikirim', 'sky'],
            ['order_status', 'completed', 'Selesai', 'green'],
            ['order_status', 'cancelled', 'Dibatalkan', 'red'],
            ['shipping_type', 'store_pickup', 'Ambil di Toko', 'slate'],
            ['shipping_type', 'store_delivery', 'Antar Toko', 'slate'],
            ['shipping_type', 'platform_delivery', 'Antar Platform', 'slate'],
            ['shipping_type', 'courier', 'Kurir', 'slate'],
            ['shipping_type', 'io_express', 'IO Express', 'slate'],
            ['shipping_type', 'io_same_day', 'IO Same Day', 'slate'],
            ['shipping_type', 'custom', 'Kustom', 'slate'],
        ];

        $now = now();
        $order = [];
        foreach ($rows as [$group, $key, $label, $color]) {
            $order[$group] = ($order[$group] ?? 0) + 1;
            DB::table('label_configs')->insert([
                'group' => $group, 'key' => $key, 'label' => $label, 'color' => $color,
                'sort_order' => $order[$group], 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('label_configs');
    }
};
