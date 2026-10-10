<?php

namespace App\Models;

use App\Support\Enums\PromotionType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Promotion extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'store_id',
        'flash_sale_slot_id',
        'name',
        'code',
        'type',
        'discount_value',
        'minimum_purchase',
        'maximum_discount',
        'usage_limit',
        'usage_count',
        'banner_path',
        'starts_at',
        'ends_at',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'type' => PromotionType::class,
            'discount_value' => 'decimal:2',
            'minimum_purchase' => 'decimal:2',
            'maximum_discount' => 'decimal:2',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function flashSaleSlot(): BelongsTo
    {
        return $this->belongsTo(FlashSaleSlot::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function products(): BelongsToMany
    {
        return $this->belongsToMany(Product::class, 'promotion_products')->using(PromotionProduct::class);
    }

    public function categories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class, 'promotion_categories');
    }

    public function isCurrentlyActive(): bool
    {
        $now = now();

        return $this->is_active && $this->starts_at <= $now && $this->ends_at >= $now;
    }
}
