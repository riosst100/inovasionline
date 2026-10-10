<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Relations\Pivot;

class PromotionProduct extends Pivot
{
    use HasUlids;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $table = 'promotion_products';
}
