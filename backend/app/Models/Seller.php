<?php

namespace App\Models;

use App\Support\Enums\SellerApplicationStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Seller extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'seller_application_id',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'status' => SellerApplicationStatus::class,
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function application(): BelongsTo
    {
        return $this->belongsTo(SellerApplication::class, 'seller_application_id');
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class);
    }
}
