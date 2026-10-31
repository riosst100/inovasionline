<?php

namespace App\Console\Commands;

use App\Models\Order;
use App\Models\WalletTopup;
use App\Services\MidtransService;
use App\Services\OrderCancellationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Console\Command;

class ExpireUnpaidPayments extends Command
{
    private const PROCESSING_LIMIT_MINUTES = 30;

    protected $signature = 'payments:expire-unpaid';

    protected $description = 'Cancel gateway orders and expire top-ups whose Midtrans payment window has passed unpaid';

    public function handle(MidtransService $midtrans, OrderCancellationService $cancellation): int
    {
        $cancelled = 0;
        $expired = 0;

        Order::query()
            ->where('status', OrderStatus::PENDING)
            ->where('payment_status', PaymentStatus::UNPAID)
            ->whereNotNull('payment_token')
            ->where('payment_expires_at', '<', now())
            ->each(function (Order $order) use ($midtrans, $cancellation, &$cancelled) {
                // Midtrans may know about a payment the webhook missed; settle that first.
                $order = $midtrans->syncStatus($order);

                if ($order->status === OrderStatus::PENDING && $order->payment_status === PaymentStatus::UNPAID
                    && $order->canTransitionTo(OrderStatus::CANCELLED)) {
                    $order->update(['payment_status' => PaymentStatus::FAILED]);
                    $cancellation->cancel($order, 'system');
                    $cancelled++;
                }
            });

        WalletTopup::query()
            ->where('status', WalletTopup::STATUS_PENDING)
            ->whereNotNull('payment_token')
            ->where('payment_expires_at', '<', now())
            ->each(function (WalletTopup $topup) use ($midtrans, &$expired) {
                $topup = $midtrans->syncTopupStatus($topup);

                if ($topup->status === WalletTopup::STATUS_PENDING) {
                    $topup->update(['status' => WalletTopup::STATUS_EXPIRED]);
                    $expired++;
                }
            });

        // Orders stuck in "Diproses" are cancelled; the time counts from when they entered it.
        $stuck = 0;
        Order::query()
            ->where('status', OrderStatus::PROCESSING)
            ->each(function (Order $order) use ($cancellation, &$stuck) {
                $since = collect($order->status_history ?? [])
                    ->where('status', OrderStatus::PROCESSING->value)
                    ->pluck('at')
                    ->last();

                if (! $since || now()->subMinutes(self::PROCESSING_LIMIT_MINUTES)->lt($since)) {
                    return;
                }

                if ($order->canTransitionTo(OrderStatus::CANCELLED)) {
                    $cancellation->cancel($order, 'system', 'Pesanan tidak diproses lebih dari '.self::PROCESSING_LIMIT_MINUTES.' menit.');
                    $stuck++;
                }
            });

        $this->info("{$cancelled} unpaid order(s) cancelled, {$stuck} stuck order(s) cancelled, {$expired} top-up(s) expired.");

        return self::SUCCESS;
    }
}
