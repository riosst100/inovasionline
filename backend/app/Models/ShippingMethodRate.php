<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShippingMethodRate extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'shipping_method_id',
        'district_code',
        'village_code',
        'fee',
    ];

    protected function casts(): array
    {
        return [
            'fee' => 'decimal:2',
        ];
    }

    public function shippingMethod(): BelongsTo
    {
        return $this->belongsTo(ShippingMethod::class);
    }
}
