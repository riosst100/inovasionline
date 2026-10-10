<?php

namespace App\Models;

use App\Support\Enums\PhotographerApplicationStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Photographer extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'photographer_application_id',
        'status',
        'display_name',
    ];

    protected function casts(): array
    {
        return [
            'status' => PhotographerApplicationStatus::class,
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function application(): BelongsTo
    {
        return $this->belongsTo(PhotographerApplication::class, 'photographer_application_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(PhotoEvent::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(Photo::class);
    }
}
