<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserAddress extends Model
{
    use HasUlids;

    /** The labels a buyer can pick from; keep in sync with the app. */
    public const LABELS = ['Rumah', 'Kantor', 'Kost', 'Kontrakan', 'Hotel'];

    protected $fillable = [
        'label',
        'recipient_name',
        'recipient_phone',
        'province_code',
        'city_code',
        'district_code',
        'village_code',
        'address_detail',
        'last_used_at',
    ];

    protected function casts(): array
    {
        return [
            'last_used_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Most recently added or used first. */
    public function scopeRecentFirst(Builder $query): Builder
    {
        return $query->orderByDesc('last_used_at')->orderByDesc('created_at');
    }
}
