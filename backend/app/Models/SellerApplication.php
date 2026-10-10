<?php

namespace App\Models;

use App\Support\Enums\SellerApplicationStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellerApplication extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'user_id',
        'full_name',
        'email',
        'phone',
        'store_name',
        'store_slug',
        'business_type',
        'main_category_id',
        'business_description',
        'address',
        'province',
        'city',
        'district',
        'postal_code',
        'latitude',
        'longitude',
        'logo_path',
        'cover_path',
        'status',
        'rejection_reason',
        'reviewed_by',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => SellerApplicationStatus::class,
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
            'reviewed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function mainCategory(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'main_category_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
