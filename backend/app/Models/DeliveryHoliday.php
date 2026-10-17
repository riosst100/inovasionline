<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A date with no scheduled deliveries; shipping_method_id null = every method. */
class DeliveryHoliday extends Model
{
    use HasUlids;

    protected $fillable = ['shipping_method_id', 'date', 'name'];

    protected function casts(): array
    {
        return [
            'date' => 'date',
        ];
    }

    public function shippingMethod(): BelongsTo
    {
        return $this->belongsTo(ShippingMethod::class);
    }

    /** Holidays that apply to the given method (its own plus the global ones). */
    public function scopeForMethod(Builder $query, string $shippingMethodId): Builder
    {
        return $query->where(fn ($q) => $q->whereNull('shipping_method_id')->orWhere('shipping_method_id', $shippingMethodId));
    }
}
