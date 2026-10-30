<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Banner extends Model
{
    use HasFactory, HasUlids;

    /** Home hero carousel. */
    public const PLACEMENT_SLIDER = 'slider';

    /** Image popup shown on opening the app (at most once a day per device). */
    public const PLACEMENT_POPUP = 'popup';

    public const PLACEMENTS = [self::PLACEMENT_SLIDER, self::PLACEMENT_POPUP];

    protected $fillable = [
        'name',
        'image_path',
        'link_url',
        'placement',
        'is_active',
        'starts_on',
        'ends_on',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'starts_on' => 'date:Y-m-d',
            'ends_on' => 'date:Y-m-d',
        ];
    }
}
