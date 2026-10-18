<?php

namespace App\Models;

use App\Models\Concerns\RollsTiers;
use Illuminate\Database\Eloquent\Model;

/**
 * How the one-time "saldo belanja" bonus is rolled: a tier is picked by its
 * weight (%), then an amount inside it in multiples of step.
 */
class WalletBonusSetting extends Model
{
    use RollsTiers;

    public const DEFAULT_TIERS = [
        ['from' => 1000, 'to' => 5000, 'weight' => 75],
        ['from' => 5500, 'to' => 9500, 'weight' => 20],
        ['from' => 10000, 'to' => 20000, 'weight' => 5],
    ];

    protected $fillable = ['is_active', 'step', 'tiers'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'step' => 'integer',
            'tiers' => 'array',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => true,
            'step' => 500,
            'tiers' => self::DEFAULT_TIERS,
        ]);
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'step' => (int) $this->step,
            'tiers' => $this->tiersPayload(),
        ];
    }
}
