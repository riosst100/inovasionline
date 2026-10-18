<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A rewarded-ad view AdMob confirmed for a user (see AdmobSsvController). */
class AdReward extends Model
{
    use HasUlids;

    /** Watched to unlock the one-time saldo bonus. */
    public const PURPOSE_BONUS = 'bonus';

    /** Watched to fill the home screen's reward chest. */
    public const PURPOSE_CHEST = 'chest';

    protected $fillable = ['user_id', 'transaction_id', 'ad_unit', 'purpose', 'consumed_at'];

    protected function casts(): array
    {
        return ['consumed_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
