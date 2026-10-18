<?php

namespace App\Models;

use App\Models\Concerns\RollsTiers;
use Illuminate\Database\Eloquent\Model;

/**
 * Iklan > Peti Hadiah: up to chests_per_day chests a day on the home screen,
 * each opened by one rewarded ad and paying a random saldo belanja amount.
 */
class AdChestSetting extends Model
{
    use RollsTiers;

    /**
     * Sized to rewarded-ad revenue in Indonesia (roughly Rp30–80 per completed
     * view): about Rp24 per chest on average, so a chest pays out less than
     * the ad that opens it earns.
     */
    public const DEFAULT_TIERS = [
        ['from' => 10, 'to' => 20, 'weight' => 85],
        ['from' => 30, 'to' => 50, 'weight' => 13],
        ['from' => 100, 'to' => 500, 'weight' => 2],
    ];

    protected $fillable = ['is_active', 'chests_per_day', 'daily_budget', 'step', 'tiers'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'chests_per_day' => 'integer',
            'daily_budget' => 'integer',
            'step' => 'integer',
            'tiers' => 'array',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => true,
            'chests_per_day' => 5,
            'daily_budget' => 100000,
            'step' => 5,
            'tiers' => self::DEFAULT_TIERS,
        ]);
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'chests_per_day' => (int) $this->chests_per_day,
            'daily_budget' => (int) $this->daily_budget,
            'step' => (int) $this->step,
            'tiers' => $this->tiersPayload(),
        ];
    }
}
