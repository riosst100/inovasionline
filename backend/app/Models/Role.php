<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Role extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'name',
        'slug',
        'description',
        'permissions',
        'is_system',
    ];

    protected function casts(): array
    {
        return [
            'permissions' => 'array',
            'is_system' => 'boolean',
        ];
    }

    /** The courier role, created on first use (by the Kurir page or its import). */
    public static function driver(): self
    {
        return self::firstOrCreate(
            ['slug' => 'driver'],
            [
                'name' => 'Driver',
                'description' => 'Petugas kurir pengantaran barang dan update status ekspedisi pengiriman.',
                'permissions' => ['orders.view', 'delivery.view', 'delivery.update'],
                'is_system' => false,
            ]
        );
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }
}
