<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderSetting extends Model
{
    public const DEFAULT_CANCEL_WINDOW_SECONDS = 60;

    public const DEFAULT_PAYLATER_MIN_TRANSACTIONS = 3;
    public const DEFAULT_PAYLATER_DUE_DAYS = 7;

    protected $fillable = ['buyer_cancel_window_seconds', 'paylater_min_transactions', 'paylater_due_days'];

    protected function casts(): array
    {
        return [
            'buyer_cancel_window_seconds' => 'integer',
            'paylater_min_transactions' => 'integer',
            'paylater_due_days' => 'integer',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'buyer_cancel_window_seconds' => self::DEFAULT_CANCEL_WINDOW_SECONDS,
            'paylater_min_transactions' => self::DEFAULT_PAYLATER_MIN_TRANSACTIONS,
            'paylater_due_days' => self::DEFAULT_PAYLATER_DUE_DAYS,
        ]);
    }

    public function toPayload(): array
    {
        return [
            'buyer_cancel_window_seconds' => (int) $this->buyer_cancel_window_seconds,
            'paylater_min_transactions' => (int) ($this->paylater_min_transactions ?? self::DEFAULT_PAYLATER_MIN_TRANSACTIONS),
            'paylater_due_days' => (int) ($this->paylater_due_days ?? self::DEFAULT_PAYLATER_DUE_DAYS),
        ];
    }
}
