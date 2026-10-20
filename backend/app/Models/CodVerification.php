<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One-time face liveness check a customer passes before paying by COD; the recording is kept for review. */
class CodVerification extends Model
{
    use HasUlids;

    public const STATUS_VERIFIED = 'verified';

    public const STATUS_REVOKED = 'revoked';

    protected $fillable = [
        'user_id',
        'video_path',
        'steps',
        'device',
        'ip_address',
        'status',
        'revoked_reason',
        'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'steps' => 'array',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
