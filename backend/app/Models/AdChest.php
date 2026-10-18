<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A reward chest a user opened (see AdChestService). */
class AdChest extends Model
{
    use HasUlids;

    protected $fillable = ['user_id', 'amount', 'wallet_transaction_id'];

    protected function casts(): array
    {
        return ['amount' => 'integer'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
