<?php

namespace App\Models;

use App\Support\Enums\ShippingMethodType;
use App\Support\Enums\ShippingRateType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ShippingMethod extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'store_id',
        'type',
        'rate_type',
        'name',
        'description',
        'base_fee',
        'fee_per_km',
        'min_order_amount',
        'max_distance_km',
        'estimated_delivery_time',
        'pickup_address',
        'pickup_instructions',
        'pickup_hours',
        'delivery_radius_km',
        'free_shipping_min_amount',
        'is_enabled',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'type' => ShippingMethodType::class,
            'rate_type' => ShippingRateType::class,
            'base_fee' => 'decimal:2',
            'fee_per_km' => 'decimal:2',
            'min_order_amount' => 'decimal:2',
            'max_distance_km' => 'decimal:2',
            'pickup_hours' => 'array',
            'delivery_radius_km' => 'decimal:2',
            'free_shipping_min_amount' => 'decimal:2',
            'is_enabled' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function rates(): HasMany
    {
        return $this->hasMany(ShippingMethodRate::class);
    }
}
