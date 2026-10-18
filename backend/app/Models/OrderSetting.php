<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderSetting extends Model
{
    public const DEFAULT_CANCEL_WINDOW_SECONDS = 60;

    protected $fillable = ['buyer_cancel_window_seconds'];

    protected function casts(): array
    {
        return [
            'buyer_cancel_window_seconds' => 'integer',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'buyer_cancel_window_seconds' => self::DEFAULT_CANCEL_WINDOW_SECONDS,
        ]);
    }

    public function toPayload(): array
    {
        return [
            'buyer_cancel_window_seconds' => (int) $this->buyer_cancel_window_seconds,
        ];
    }
}
