<?php

namespace App\Models;

use App\Support\Enums\PhotoPurchaseStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class PhotoPurchase extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'photo_id',
        'matched_face_index',
        'price',
        'status',
        'purchased_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => PhotoPurchaseStatus::class,
            'price' => 'decimal:2',
            'purchased_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function photo(): BelongsTo
    {
        return $this->belongsTo(Photo::class);
    }
}
