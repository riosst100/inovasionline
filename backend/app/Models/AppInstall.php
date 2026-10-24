<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppInstall extends Model
{
    use HasUlids;

    /** An install that pinged within this window counts as online right now. */
    public const ONLINE_MINUTES = 5;

    protected $fillable = [
        'install_id',
        'user_id',
        'platform',
        'app_version',
        'build_number',
        'current_screen',
        'first_seen_at',
        'last_seen_at',
    ];

    protected function casts(): array
    {
        return [
            'first_seen_at' => 'datetime',
            'last_seen_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
