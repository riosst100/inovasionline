<?php

namespace App\Services;

use App\Models\Order;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Support\Enums\OrderStatus;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class OrderCancellationService
{
    public function cancel(Order $order, string $by): Order
    {
        if (! $order->canTransitionTo(OrderStatus::CANCELLED)) {
            throw new RuntimeException('Order cannot be cancelled.');
        }

        return DB::transaction(function () use ($order, $by) {
            $order->load('items');

            foreach ($order->items as $item) {
                if ($item->product_variant_id) {
                    ProductVariant::where('id', $item->product_variant_id)->increment('stock', $item->quantity);
                } elseif ($item->product_id) {
                    Product::where('id', $item->product_id)->increment('stock', $item->quantity);
                }
            }

            $order->update([
                'status' => OrderStatus::CANCELLED,
                'status_history' => [
                    ...$order->status_history,
                    ['status' => 'cancelled', 'at' => now()->toIso8601String(), 'by' => $by],
                ],
                'cancelled_at' => now(),
            ]);

            return $order->fresh();
        });
    }
}
