<?php

namespace App\Services;

use App\Models\Order;
use App\Models\ProductVariant;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class OrderCancellationService
{
    public function __construct(
        private readonly ProductStockService $stockService = new ProductStockService,
        private readonly WalletService $walletService = new WalletService,
    ) {}

    public function cancel(Order $order, string $by, ?string $reason = null): Order
    {
        if (! $order->canTransitionTo(OrderStatus::CANCELLED)) {
            throw new RuntimeException('Order cannot be cancelled.');
        }

        return DB::transaction(function () use ($order, $by, $reason) {
            $order->load('items');

            foreach ($order->items as $item) {
                if ($item->product_variant_id) {
                    ProductVariant::where('id', $item->product_variant_id)->increment('stock', $item->quantity);
                } elseif ($item->product_id) {
                    $this->stockService->release($item->product_id, $item->stock_allocations, $item->quantity);
                }
            }

            $order->update([
                'status' => OrderStatus::CANCELLED,
                'status_history' => [
                    ...$order->status_history,
                    ['status' => 'cancelled', 'at' => now()->toIso8601String(), 'by' => $by],
                ],
                'cancelled_at' => now(),
                'cancelled_by' => str_starts_with($by, 'admin') ? 'admin' : $by,
                'cancel_reason' => $reason,
            ]);

            // Whatever the original payment method, paid money always comes back as balance.
            if ($order->payment_status === PaymentStatus::PAID) {
                $this->walletService->refundOrder($order);
            }

            return $order->fresh();
        });
    }
}
