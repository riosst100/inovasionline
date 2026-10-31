<?php

namespace App\Services;

use App\Models\MidtransSetting;
use App\Models\Order;
use App\Models\WalletTopup;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class MidtransService
{
    public function __construct(
        private readonly OrderCancellationService $cancellationService,
        private readonly WalletService $walletService = new WalletService,
    ) {}

    /**
     * Create (or reuse a still-valid) Snap transaction for the order.
     */
    public function createSnapTransaction(Order $order): Order
    {
        if ($order->payment_status === PaymentStatus::PAID) {
            throw new RuntimeException('Order is already paid.');
        }

        if ($order->status !== OrderStatus::PENDING) {
            throw new RuntimeException('Order is no longer payable.');
        }

        if ($order->payment_token && $order->payment_expires_at?->isFuture()) {
            return $order;
        }

        $order->loadMissing(['user', 'paymentMethod']);
        $channel = $order->paymentMethod?->gateway_channel;
        $address = $order->delivery_address ?? [];

        // Midtrans rejects a reused order_id, so a retry after an expired token gets a suffix.
        $midtransOrderId = $order->payment_token
            ? $order->order_number.'~'.now()->timestamp
            : $order->order_number;

        $snap = $this->requestSnap(expiryMinutes: MidtransSetting::current()->order_expiry_minutes ?: MidtransSetting::DEFAULT_ORDER_EXPIRY_MINUTES, payload: [
            // A single enabled channel makes Snap skip its own method list.
            'enabled_payments' => $channel ? [$channel] : null,
            'transaction_details' => [
                'order_id' => $midtransOrderId,
                'gross_amount' => (int) round((float) $order->grand_total),
            ],
            'customer_details' => [
                'first_name' => $address['recipient_name'] ?? $order->user?->name,
                'email' => $order->user?->email,
                'phone' => $address['recipient_phone'] ?? null,
            ],
        ]);

        $order->update([
            ...$snap,
            'midtrans_order_id' => $midtransOrderId,
        ]);

        return $order->fresh();
    }

    /**
     * Snap transaction for a balance top-up; the buyer picks any channel on the Midtrans page.
     */
    public function createTopupTransaction(WalletTopup $topup): WalletTopup
    {
        $topup->loadMissing('user');

        $snap = $this->requestSnap(expiryMinutes: MidtransSetting::current()->topup_expiry_minutes ?: MidtransSetting::DEFAULT_TOPUP_EXPIRY_MINUTES, payload: [
            'transaction_details' => [
                'order_id' => $topup->topup_number,
                'gross_amount' => (int) round((float) $topup->amount),
            ],
            'customer_details' => [
                'first_name' => $topup->user?->name,
                'email' => $topup->user?->email,
                'phone' => $topup->user?->phone,
            ],
            'item_details' => [[
                'id' => 'topup',
                'name' => 'Top Up Saldo Inovasi',
                'price' => (int) round((float) $topup->amount),
                'quantity' => 1,
            ]],
        ]);

        $topup->update($snap);

        return $topup->fresh();
    }

    /**
     * Voids an unpaid transaction (VA number, QR) so a cancelled order cannot be paid
     * afterwards. Best effort: Midtrans answers 404 when no channel was picked yet.
     */
    public function cancelTransaction(Order $order): void
    {
        $serverKey = MidtransSetting::current()->serverKey();

        if ($serverKey === '' || ! $order->payment_token) {
            return;
        }

        $midtransOrderId = $order->midtrans_order_id ?? $order->order_number;

        try {
            Http::withBasicAuth($serverKey, '')
                ->acceptJson()
                ->timeout(15)
                ->post($this->apiUrl().'/v2/'.rawurlencode($midtransOrderId).'/cancel');
        } catch (\Throwable $e) {
            report($e);
        }
    }

    public function isValidSignature(array $payload): bool
    {
        $expected = hash(
            'sha512',
            ($payload['order_id'] ?? '').($payload['status_code'] ?? '').($payload['gross_amount'] ?? '').MidtransSetting::current()->serverKey()
        );

        return hash_equals($expected, (string) ($payload['signature_key'] ?? ''));
    }

    /**
     * Apply a Midtrans HTTP notification to the matching order or top-up. Idempotent.
     */
    public function handleNotification(array $payload): void
    {
        $midtransOrderId = (string) ($payload['order_id'] ?? '');

        if (str_starts_with($midtransOrderId, WalletTopup::NUMBER_PREFIX)) {
            $this->handleTopupNotification($payload);

            return;
        }

        $orderNumber = explode('~', $midtransOrderId)[0];
        $order = Order::where('order_number', $orderNumber)->first();

        if (! $order) {
            throw new RuntimeException('Order not found.');
        }

        if (abs((float) ($payload['gross_amount'] ?? 0) - (float) $order->grand_total) > 1) {
            throw new RuntimeException('Amount mismatch.');
        }

        $transactionStatus = $payload['transaction_status'] ?? '';
        $fraudStatus = $payload['fraud_status'] ?? 'accept';

        DB::transaction(function () use ($order, $payload, $transactionStatus, $fraudStatus) {
            $order = Order::whereKey($order->id)->lockForUpdate()->first();
            $isRefund = in_array($transactionStatus, ['refund', 'partial_refund'], true);

            // Already settled (or settled and refunded to the balance): nothing left to do.
            if (in_array($order->payment_status, [PaymentStatus::PAID, PaymentStatus::REFUNDED], true) && ! $isRefund) {
                return;
            }

            $order->fill([
                'midtrans_transaction_id' => $payload['transaction_id'] ?? $order->midtrans_transaction_id,
                'midtrans_payment_type' => $payload['payment_type'] ?? $order->midtrans_payment_type,
            ]);

            if ($transactionStatus === 'settlement' || ($transactionStatus === 'capture' && $fraudStatus === 'accept')) {
                $order->payment_status = PaymentStatus::PAID;
                $order->paid_at = now();

                // Paid orders start preparation right away, same as non-gateway orders.
                if ($order->status === OrderStatus::PENDING) {
                    $order->status = OrderStatus::PROCESSING;
                    $order->status_history = [
                        ...($order->status_history ?? []),
                        ['status' => OrderStatus::PROCESSING->value, 'at' => now()->toIso8601String(), 'by' => 'system'],
                    ];
                }

                $order->save();

                // Paid after it was already cancelled (e.g. VA paid before the void went through):
                // the money goes to the buyer's balance instead of being lost.
                if ($order->status === OrderStatus::CANCELLED) {
                    $this->walletService->refundOrder($order);
                }

                return;
            }

            if ($isRefund) {
                $order->payment_status = PaymentStatus::REFUNDED;
            } elseif (in_array($transactionStatus, ['deny', 'cancel', 'expire', 'failure'], true)) {
                $order->payment_status = PaymentStatus::FAILED;
                $order->save();

                if ($order->canTransitionTo(OrderStatus::CANCELLED)) {
                    $this->cancellationService->cancel($order, 'system');
                }

                return;
            }

            $order->save();
        });
    }

    /**
     * Pull the latest transaction status from Midtrans and apply it, for when the
     * HTTP notification is late or cannot reach this server (e.g. local dev).
     */
    public function syncStatus(Order $order): Order
    {
        if (! $order->payment_token || $order->payment_status === PaymentStatus::PAID) {
            return $order;
        }

        if ($status = $this->fetchStatus($order->midtrans_order_id ?? $order->order_number)) {
            $this->handleNotification($status);
        }

        return $order->fresh();
    }

    public function syncTopupStatus(WalletTopup $topup): WalletTopup
    {
        if (! $topup->payment_token || $topup->status !== WalletTopup::STATUS_PENDING) {
            return $topup;
        }

        if ($status = $this->fetchStatus($topup->topup_number)) {
            $this->handleNotification($status);
        }

        return $topup->fresh();
    }

    /**
     * Admin detail view: re-checks a running top-up, or backfills the payment details of
     * one settled before they were stored.
     */
    public function refreshTopup(WalletTopup $topup): WalletTopup
    {
        if (! $topup->payment_token) {
            return $topup;
        }

        if ($topup->status === WalletTopup::STATUS_PENDING || ($topup->status === WalletTopup::STATUS_PAID && ! $topup->payment_details)) {
            if ($status = $this->fetchStatus($topup->topup_number)) {
                $this->handleNotification($status);
            }
        }

        return $topup->fresh();
    }

    private function handleTopupNotification(array $payload): void
    {
        $topup = WalletTopup::where('topup_number', $payload['order_id'] ?? '')->first();

        if (! $topup) {
            throw new RuntimeException('Top-up not found.');
        }

        if (abs((float) ($payload['gross_amount'] ?? 0) - (float) $topup->amount) > 1) {
            throw new RuntimeException('Amount mismatch.');
        }

        $transactionStatus = $payload['transaction_status'] ?? '';
        $fraudStatus = $payload['fraud_status'] ?? 'accept';

        DB::transaction(function () use ($topup, $payload, $transactionStatus, $fraudStatus) {
            $topup = WalletTopup::whereKey($topup->id)->lockForUpdate()->first();

            $topup->fill([
                'midtrans_transaction_id' => $payload['transaction_id'] ?? $topup->midtrans_transaction_id,
                'midtrans_payment_type' => $payload['payment_type'] ?? $topup->midtrans_payment_type,
                'payment_details' => Arr::except($payload, ['signature_key']),
            ]);

            // Already credited: only keep the payment details fresh.
            if ($topup->getOriginal('status') === WalletTopup::STATUS_PAID) {
                $topup->save();

                return;
            }

            if ($transactionStatus === 'settlement' || ($transactionStatus === 'capture' && $fraudStatus === 'accept')) {
                $topup->status = WalletTopup::STATUS_PAID;
                $topup->paid_at = now();
                $topup->save();
                $this->walletService->creditTopup($topup);

                return;
            }

            if ($transactionStatus === 'expire') {
                $topup->status = WalletTopup::STATUS_EXPIRED;
            } elseif (in_array($transactionStatus, ['deny', 'cancel', 'failure'], true)) {
                $topup->status = WalletTopup::STATUS_FAILED;
            }

            $topup->save();
        });
    }

    /**
     * @return array{payment_token: string, payment_redirect_url: string, payment_expires_at: \Illuminate\Support\Carbon}
     */
    private function requestSnap(array $payload, ?int $expiryMinutes = null): array
    {
        $serverKey = MidtransSetting::current()->serverKey();

        if ($serverKey === '') {
            throw new RuntimeException('Payment gateway is not configured.');
        }

        $expiryMinutes ??= (int) config('services.midtrans.expiry_minutes', 1440);

        // Lets a local/staging server receive its own notifications (e.g. via an ngrok URL)
        // while the dashboard Notification URL keeps pointing at production.
        $notificationUrl = (string) config('services.midtrans.notification_url');

        $response = Http::withBasicAuth($serverKey, '')
            ->acceptJson()
            ->asJson()
            ->timeout(15)
            ->when($notificationUrl !== '', fn ($http) => $http->withHeaders(['X-Override-Notification' => $notificationUrl]))
            ->post($this->snapUrl().'/snap/v1/transactions', array_filter([
                ...$payload,
                'expiry' => [
                    'unit' => 'minutes',
                    'duration' => $expiryMinutes,
                ],
                // The app's webview closes on any redirect carrying transaction_status,
                // so this works without configuring a Finish URL in the dashboard.
                'callbacks' => [
                    'finish' => $this->finishUrl(),
                ],
            ]));

        if (! $response->successful() || ! $response->json('token')) {
            report(new RuntimeException('Midtrans Snap error: '.$response->body()));

            throw new RuntimeException('Failed to create payment transaction.');
        }

        return [
            'payment_token' => $response->json('token'),
            'payment_redirect_url' => $response->json('redirect_url'),
            'payment_expires_at' => now()->addMinutes($expiryMinutes),
        ];
    }

    /** Midtrans answers with status_code 404 in the body until the buyer picks a payment channel. */
    private function fetchStatus(string $midtransOrderId): ?array
    {
        $serverKey = MidtransSetting::current()->serverKey();

        if ($serverKey === '') {
            return null;
        }

        $response = Http::withBasicAuth($serverKey, '')
            ->acceptJson()
            ->timeout(15)
            ->get($this->apiUrl().'/v2/'.rawurlencode($midtransOrderId).'/status');

        return $response->successful() && $response->json('transaction_status') ? $response->json() : null;
    }

    private function finishUrl(): string
    {
        return rtrim((string) config('app.frontend_url'), '/').'/payment/finish';
    }

    private function apiUrl(): string
    {
        return MidtransSetting::current()->isProduction()
            ? 'https://api.midtrans.com'
            : 'https://api.sandbox.midtrans.com';
    }

    private function snapUrl(): string
    {
        return MidtransSetting::current()->isProduction()
            ? 'https://app.midtrans.com'
            : 'https://app.sandbox.midtrans.com';
    }
}
