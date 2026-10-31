<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * What the app shows as a popup right after opening: nothing, an AdMob native ad, or the
 * popup images (Banner placement "popup", each with its own days / date range). Singleton row.
 */
class LaunchPopupSetting extends Model
{
    public const MODE_OFF = 'off';

    public const MODE_ADMOB = 'admob';

    /** Own images on the days they are scheduled; AdMob on days with none. */
    public const MODE_IMAGE = 'image';

    public const MODES = [self::MODE_OFF, self::MODE_ADMOB, self::MODE_IMAGE];

    public const TIMEZONE = 'Asia/Jakarta';

    protected $fillable = ['mode', 'max_per_day'];

    protected function casts(): array
    {
        return ['max_per_day' => 'integer'];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'mode' => self::MODE_OFF,
            'max_per_day' => 1,
        ]);
    }

    public function toPayload(): array
    {
        return [
            'mode' => $this->mode,
            'max_per_day' => (int) $this->max_per_day,
        ];
    }
}
