<?php

namespace App\Models;

use App\Support\Enums\PaymentMethodType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PaymentMethod extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'type',
        'gateway_channel',
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

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function isManualAccount(): bool
    {
        return in_array($this->type?->value, PaymentMethodType::MANUAL_ACCOUNT_TYPES, true);
    }
}
