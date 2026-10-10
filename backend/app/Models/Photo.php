<?php

namespace App\Models;

use App\Support\Enums\PhotoStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Photo extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'photographer_id',
        'photo_event_id',
        'path',
        'watermarked_path',
        'embeddings',
        'price',
        'status',
        'face_count',
        'taken_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => PhotoStatus::class,
            'embeddings' => 'array',
            'price' => 'decimal:2',
            'taken_at' => 'datetime',
        ];
    }

    public function photographer(): BelongsTo
    {
        return $this->belongsTo(Photographer::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(PhotoEvent::class, 'photo_event_id');
    }

    public function matchedUsers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'photo_matches')
            ->using(PhotoMatch::class)
            ->withPivot(['confidence_score', 'matched_face_index'])
            ->withTimestamps();
    }

    public function purchases(): HasMany
    {
        return $this->hasMany(PhotoPurchase::class);
    }
}
