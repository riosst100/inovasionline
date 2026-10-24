<?php

namespace App\Models;

use App\Http\Controllers\Api\V1\Admin\WalletTopupController;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A bill the platform owes a supplier. Unpaid while paid_at is null; overdue once past due_date (WIB). */
class SupplierBill extends Model
{
    use HasUlids;

    public const STATUS_UNPAID = 'unpaid';

    public const STATUS_OVERDUE = 'overdue';

    public const STATUS_PAID = 'paid';

    protected $fillable = ['supplier_id', 'bill_number', 'bill_date', 'due_date', 'amount', 'notes', 'paid_at', 'payment_notes'];

    protected function casts(): array
    {
        return [
            'bill_date' => 'date',
            'due_date' => 'date',
            'amount' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public static function today(): string
    {
        return now(WalletTopupController::TIMEZONE)->toDateString();
    }

    public function status(): string
    {
        if ($this->paid_at) {
            return self::STATUS_PAID;
        }

        return $this->due_date && $this->due_date->toDateString() < self::today() ? self::STATUS_OVERDUE : self::STATUS_UNPAID;
    }

    public function scopeUnpaid(Builder $query): Builder
    {
        return $query->whereNull('paid_at');
    }

    public function scopeOverdue(Builder $query): Builder
    {
        return $query->whereNull('paid_at')->where('due_date', '<', self::today());
    }

    public function scopeWithStatus(Builder $query, string $status): Builder
    {
        return match ($status) {
            self::STATUS_PAID => $query->whereNotNull('paid_at'),
            self::STATUS_OVERDUE => $query->overdue(),
            // Unpaid but not (yet) overdue.
            default => $query->whereNull('paid_at')->where(fn ($q) => $q->whereNull('due_date')->orWhere('due_date', '>=', self::today())),
        };
    }
}
