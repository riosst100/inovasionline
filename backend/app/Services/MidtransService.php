<?php

namespace App\Services;

use App\Models\Order;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class MidtransService
{
    public function __construct(private readonly OrderCancellationService $cancellationService) {}

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

        $serverKey = (string) config('services.midtrans.server_key');

        if ($serverKey === '') {
            throw new RuntimeException('Payment gateway is not configured.');
        }

        $order->loadMissing('user');

        $expiryMinutes = (int) config('services.midtrans.expiry_minutes', 1440);
        $address = $order->delivery_address ?? [];

        // Midtrans rejects a reused order_id, so a retry after an expired token gets a suffix.
        $midtransOrderId = $order->payment_token
            ? $order->order_number.'~'.now()->timestamp
            : $order->order_number;

        $response = Http::withBasicAuth($serverKey, '')
            ->acceptJson()
            ->asJson()
            ->timeout(15)
            ->post($this->snapUrl().'/snap/v1/transactions', [
                'transaction_details' => [
                    'order_id' => $midtransOrderId,
                    'gross_amount' => (int) round((float) $order->grand_total),
                ],
                'customer_details' => [
                    'first_name' => $address['recipient_name'] ?? $order->user?->name,
                    'email' => $order->user?->email,
                    'phone' => $address['recipient_phone'] ?? null,
                ],
                'expiry' => [
                    'unit' => 'minutes',
                    'duration' => $expiryMinutes,
                ],
            ]);

        if (! $response->successful() || ! $response->json('token')) {
            report(new RuntimeException('Midtrans Snap error: '.$response->body()));

            throw new RuntimeException('Failed to create payment transaction.');
        }

        $order->update([
            'payment_token' => $response->json('token'),
            'payment_redirect_url' => $response->json('redirect_url'),
            'payment_expires_at' => now()->addMinutes($expiryMinutes),
        ]);

        return $order->fresh();
    }

    public function isValidSignature(array $payload): bool
    {
        $expected = hash(
            'sha512',
            ($payload['order_id'] ?? '').($payload['status_code'] ?? '').($payload['gross_amount'] ?? '').config('services.midtrans.server_key')
        );

        return hash_equals($expected, (string) ($payload['signature_key'] ?? ''));
    }

    /**
     * Apply a Midtrans HTTP notification to the matching order. Idempotent.
     */
    public function handleNotification(array $payload): void
    {
        $orderNumber = explode('~', (string) ($payload['order_id'] ?? ''))[0];
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

            if ($order->payment_status === PaymentStatus::PAID && ! $isRefund) {
                return;
            }

            $order->fill([
                'midtrans_transaction_id' => $payload['transaction_id'] ?? $order->midtrans_transaction_id,
                'midtrans_payment_type' => $payload['payment_type'] ?? $order->midtrans_payment_type,
            ]);

            if ($transactionStatus === 'settlement' || ($transactionStatus === 'capture' && $fraudStatus === 'accept')) {
                $order->payment_status = PaymentStatus::PAID;
                $order->paid_at = now();
            } elseif ($isRefund) {
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

    private function snapUrl(): string
    {
        return config('services.midtrans.is_production')
            ? 'https://app.midtrans.com'
            : 'https://app.sandbox.midtrans.com';
    }
}
