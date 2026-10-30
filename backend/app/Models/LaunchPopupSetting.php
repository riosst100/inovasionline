<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Model;

/**
 * What the app shows as a popup right after opening: nothing, an AdMob native ad, or the
 * active popup images (Banner placement "popup"). Singleton row; schedule is judged in WIB.
 */
class LaunchPopupSetting extends Model
{
    public const MODE_OFF = 'off';

    public const MODE_ADMOB = 'admob';

    public const MODE_IMAGE = 'image';

    public const MODES = [self::MODE_OFF, self::MODE_ADMOB, self::MODE_IMAGE];

    public const TIMEZONE = 'Asia/Jakarta';

    protected $fillable = ['mode', 'weekdays', 'max_per_day', 'starts_on', 'ends_on'];

    protected function casts(): array
    {
        return [
            'weekdays' => 'array',
            'max_per_day' => 'integer',
            'starts_on' => 'date:Y-m-d',
            'ends_on' => 'date:Y-m-d',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'mode' => self::MODE_OFF,
            'weekdays' => null,
            'max_per_day' => 1,
        ]);
    }

    /** Whether the schedule (date range + weekday) allows a popup on this WIB day. */
    public function allowsDay(CarbonInterface $now): bool
    {
        $today = $now->copy()->setTimezone(self::TIMEZONE)->startOfDay();

        if ($this->starts_on && $today->lt($this->starts_on->copy()->startOfDay())) {
            return false;
        }
        if ($this->ends_on && $today->gt($this->ends_on->copy()->startOfDay())) {
            return false;
        }

        $weekdays = $this->weekdays;

        return empty($weekdays) || in_array($today->isoWeekday(), array_map('intval', $weekdays), true);
    }

    public function toPayload(): array
    {
        return [
            'mode' => $this->mode,
            'weekdays' => $this->weekdays ?: null,
            'max_per_day' => (int) $this->max_per_day,
            'starts_on' => $this->starts_on?->format('Y-m-d'),
            'ends_on' => $this->ends_on?->format('Y-m-d'),
        ];
    }
}
