<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DeliverySchedule extends Model
{
    use HasUlids;

    protected $fillable = [
        'shipping_method_id',
        'label',
        'start_time',
        'end_time',
        'cutoff_minutes',
        'quota',
        'days',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'cutoff_minutes' => 'integer',
            'quota' => 'integer',
            'days' => 'array',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function shippingMethod(): BelongsTo
    {
        return $this->belongsTo(ShippingMethod::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    /** True when the window runs on the given ISO weekday (1 = Monday). */
    public function runsOn(int $isoWeekday): bool
    {
        return empty($this->days) || in_array($isoWeekday, $this->days, true);
    }

    /** "09:00 - 12:00" (the time columns come back as HH:MM:SS). */
    public function timeRange(): string
    {
        return substr($this->start_time, 0, 5).' - '.substr($this->end_time, 0, 5);
    }
}
