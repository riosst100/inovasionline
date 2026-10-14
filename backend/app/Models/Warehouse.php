<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class Warehouse extends Model
{
    use HasUlids;

    public const TYPES = ['warehouse', 'hub'];

    protected $fillable = [
        'code', 'name', 'type', 'address', 'city', 'province', 'postal_code',
        'latitude', 'longitude', 'contact_name', 'contact_phone', 'notes', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }
}
