<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class ProductAttribute extends Model
{
    use HasUlids;

    public const TYPES = ['text', 'textarea', 'number', 'boolean', 'select', 'date'];

    protected $fillable = [
        'code', 'name', 'type', 'options', 'description',
        'is_system', 'is_required', 'is_active', 'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'options' => 'array',
            'is_system' => 'boolean',
            'is_required' => 'boolean',
            'is_active' => 'boolean',
        ];
    }
}
