<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletTopup extends Model
{
    use HasUlids;

    public const STATUS_PENDING = 'pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_FAILED = 'failed';
    public const STATUS_EXPIRED = 'expired';

    /** Midtrans order_id prefix; tells top-up notifications apart from order ones. */
    public const NUMBER_PREFIX = 'TOP-';

    protected $fillable = [
        'topup_number',
        'user_id',
        'amount',
        'status',
        'payment_token',
        'payment_redirect_url',
        'payment_expires_at',
        'midtrans_transaction_id',
        'midtrans_payment_type',
        'paid_at',
        'payment_details',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'payment_expires_at' => 'datetime',
            'paid_at' => 'datetime',
            'payment_details' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    private const PAYMENT_TYPE_LABELS = [
        'bank_transfer' => 'Virtual Account',
        'echannel' => 'Mandiri Bill Payment',
        'permata' => 'Virtual Account',
        'credit_card' => 'Kartu Kredit/Debit',
        'gopay' => 'GoPay',
        'shopeepay' => 'ShopeePay',
        'qris' => 'QRIS',
        'other_qris' => 'QRIS',
        'cstore' => 'Gerai Retail',
        'akulaku' => 'Akulaku',
        'kredivo' => 'Kredivo',
        'bca_klikpay' => 'BCA KlikPay',
        'cimb_clicks' => 'CIMB Clicks',
        'danamon_online' => 'Danamon Online Banking',
        'bri_epay' => 'BRImo',
        'uob_ezpay' => 'UOB EZ Pay',
        'dana' => 'DANA',
    ];

    private const CHANNEL_NAMES = [
        'gopay' => 'GoPay',
        'shopeepay' => 'ShopeePay',
        'linkaja' => 'LinkAja',
        'airpay shopee' => 'ShopeePay',
        'permata' => 'Permata',
        'indomaret' => 'Indomaret',
        'alfamart' => 'Alfamart',
    ];

    /** Short label such as "Virtual Account BCA" or "QRIS"; null until a channel is picked. */
    public function paymentMethodLabel(): ?string
    {
        $type = $this->midtrans_payment_type;

        if (! $type) {
            return null;
        }

        $label = self::PAYMENT_TYPE_LABELS[$type] ?? ucwords(str_replace('_', ' ', $type));
        $channel = $this->paymentChannel();

        return $channel && $type !== 'echannel' ? "$label $channel" : $label;
    }

    /** Bank / store / issuer behind the payment type, e.g. "BCA", "Indomaret", "GoPay". */
    public function paymentChannel(): ?string
    {
        $d = $this->payment_details ?? [];

        $channel = match ($this->midtrans_payment_type) {
            'bank_transfer' => $d['va_numbers'][0]['bank'] ?? (isset($d['permata_va_number']) ? 'permata' : null),
            'permata' => 'permata',
            'credit_card' => $d['bank'] ?? null,
            'cstore' => $d['store'] ?? null,
            'qris', 'other_qris' => $d['issuer'] ?? $d['acquirer'] ?? null,
            default => null,
        };

        if (! $channel) {
            return null;
        }

        return self::CHANNEL_NAMES[strtolower($channel)] ?? (strlen($channel) <= 4 ? strtoupper($channel) : ucwords($channel));
    }

    /**
     * Payer-facing references from the Midtrans payload (VA number, bill key, payment code,
     * masked card, …) as label/value pairs for the admin detail.
     *
     * @return list<array{label: string, value: string}>
     */
    public function paymentFields(): array
    {
        $d = $this->payment_details ?? [];

        $fields = [
            'Bank' => $this->midtrans_payment_type === 'credit_card' || $this->midtrans_payment_type === 'bank_transfer' ? $this->paymentChannel() : null,
            'Nomor Virtual Account' => $d['va_numbers'][0]['va_number'] ?? $d['permata_va_number'] ?? null,
            'Kode Perusahaan (Biller)' => $d['biller_code'] ?? null,
            'Kode Bayar (Bill Key)' => $d['bill_key'] ?? null,
            'Gerai' => $this->midtrans_payment_type === 'cstore' ? $this->paymentChannel() : null,
            'Kode Pembayaran' => $d['payment_code'] ?? null,
            'Nomor Kartu' => $d['masked_card'] ?? null,
            'Jenis Kartu' => isset($d['card_type']) ? ucfirst($d['card_type']) : null,
            'Penerbit QRIS' => in_array($this->midtrans_payment_type, ['qris', 'other_qris'], true) ? ($d['issuer'] ?? null) : null,
            'Acquirer' => $d['acquirer'] ?? null,
            'Nomor HP / Akun' => $d['account_number'] ?? $d['phone_number'] ?? null,
            'Kode Approval' => $d['approval_code'] ?? null,
            'Merchant ID' => $d['merchant_id'] ?? null,
            'ID Transaksi Midtrans' => $this->midtrans_transaction_id,
            'Status Midtrans' => $d['transaction_status'] ?? null,
            'Waktu Transaksi' => $d['transaction_time'] ?? null,
            'Waktu Settlement' => $d['settlement_time'] ?? null,
        ];

        return collect($fields)
            ->filter(fn ($v) => $v !== null && $v !== '')
            ->map(fn ($v, $label) => ['label' => $label, 'value' => (string) $v])
            ->values()
            ->all();
    }
}
