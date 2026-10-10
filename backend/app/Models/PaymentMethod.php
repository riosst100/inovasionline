<?php

namespace App\Models;

use App\Support\Enums\PaymentMethodType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentMethod extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'store_id',
        'type',
        'name',
        'description',
        'instructions',
        'bank_name',
        'account_number',
        'account_holder_name',
        'is_enabled',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'type' => PaymentMethodType::class,
            'is_enabled' => 'boolean',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
