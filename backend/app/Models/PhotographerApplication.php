<?php

namespace App\Models;

use App\Support\Enums\PhotographerApplicationStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PhotographerApplication extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'user_id',
        'full_name',
        'email',
        'phone',
        'business_name',
        'portfolio_url',
        'id_card_path',
        'status',
        'rejection_reason',
        'reviewed_by',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => PhotographerApplicationStatus::class,
            'reviewed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
