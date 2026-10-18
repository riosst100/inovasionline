<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletTransaction extends Model
{
    use HasUlids;

    public const TYPE_TOPUP = 'topup';
    public const TYPE_PAYMENT = 'payment';
    public const TYPE_REFUND = 'refund';
    public const TYPE_ADJUSTMENT = 'adjustment';
    public const TYPE_BONUS = 'bonus';
    public const TYPE_AD_CHEST = 'ad_chest';

    protected $fillable = [
        'user_id',
        'type',
        'amount',
        'balance_after',
        'description',
        'order_id',
        'wallet_topup_id',
        'admin_user_id',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'balance_after' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function topup(): BelongsTo
    {
        return $this->belongsTo(WalletTopup::class, 'wallet_topup_id');
    }

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class);
    }
}
