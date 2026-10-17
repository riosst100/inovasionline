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
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'payment_expires_at' => 'datetime',
            'paid_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
