<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** The device and network an order was placed from, frozen at checkout. */
class OrderDeviceLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'order_id',
        'user_id',
        'install_id',
        'device_id',
        'device_name',
        'device_brand',
        'device_model',
        'os_version',
        'is_emulator',
        'device_details',
        'app_version',
        'build_number',
        'ip_address',
        'user_agent',
        'latitude',
        'longitude',
        'location_accuracy',
        'location_at',
    ];

    protected function casts(): array
    {
        return [
            'is_emulator' => 'boolean',
            'device_details' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
            'location_accuracy' => 'float',
            'location_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
