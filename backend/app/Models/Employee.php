<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

/** Karyawan. salary_amount is paid per salary_type unit: per order handled, per month, or per delivery. */
class Employee extends Model
{
    use HasUlids;

    public const SALARY_TYPES = ['per_order', 'monthly', 'per_delivery'];

    protected $fillable = ['name', 'phone', 'position', 'salary_type', 'salary_amount', 'is_active', 'notes'];

    protected function casts(): array
    {
        return [
            'salary_amount' => 'decimal:2',
            'is_active' => 'boolean',
        ];
    }
}
