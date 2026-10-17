<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Orders no longer wait for a manual confirmation: non-gateway orders start as
 * processing. Move the ones still stuck in pending along, since nothing would
 * confirm them anymore. Unpaid online payments stay pending until Midtrans settles.
 */
return new class extends Migration
{
    public function up(): void
    {
        $now = now()->toIso8601String();

        DB::table('orders')
            ->leftJoin('payment_methods', 'payment_methods.id', '=', 'orders.payment_method_id')
            ->where('orders.status', 'pending')
            ->where(fn ($q) => $q
                ->whereNull('payment_methods.type')
                ->orWhere('payment_methods.type', '!=', 'payment_gateway')
                ->orWhere('orders.payment_status', 'paid'))
            ->select('orders.id', 'orders.status_history')
            ->orderBy('orders.id')
            ->each(function ($order) use ($now) {
                $history = json_decode($order->status_history ?? '[]', true) ?: [];
                $history[] = ['status' => 'processing', 'at' => $now, 'by' => 'system'];

                DB::table('orders')->where('id', $order->id)->update([
                    'status' => 'processing',
                    'status_history' => json_encode($history),
                    'updated_at' => now(),
                ]);
            });
    }

    public function down(): void
    {
        // Data-only change; the previous "pending" state is not restored.
    }
};
