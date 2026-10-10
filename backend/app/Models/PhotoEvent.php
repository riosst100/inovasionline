<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class PhotoEvent extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'photographer_id',
        'title',
        'slug',
        'event_date',
        'cover_photo_path',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'event_date' => 'date',
        ];
    }

    public function photographer(): BelongsTo
    {
        return $this->belongsTo(Photographer::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(Photo::class);
    }
}
