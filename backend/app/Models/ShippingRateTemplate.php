<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ShippingRateTemplate extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'name',
        'description',
    ];

    public function rows(): HasMany
    {
        return $this->hasMany(ShippingRateTemplateRow::class);
    }
}
