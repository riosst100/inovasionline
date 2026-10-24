<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A number from someone's phone book. `phone` is normalized with
 * PhoneNumber::normalize, the same format as users.phone, so the two can be
 * joined directly to find which contacts already have an account.
 */
class UserContact extends Model
{
    use HasUlids;

    protected $fillable = [
        'install_id',
        'user_id',
        'name',
        'phone',
    ];

    /** Who uploaded this contact; null while that install is still a guest. */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** The registered account this number belongs to, if any. */
    public function matchedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'phone', 'phone');
    }
}
