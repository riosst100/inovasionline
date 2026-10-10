<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShippingRateTemplateRow extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'shipping_rate_template_id',
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

    public function template(): BelongsTo
    {
        return $this->belongsTo(ShippingRateTemplate::class, 'shipping_rate_template_id');
    }
}
