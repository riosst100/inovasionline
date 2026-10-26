<?php

namespace App\Support;

/**
 * The `device` block the customer app sends (DeviceDetails.collect() in the
 * Flutter app), shared by the presence heartbeat and checkout. Self-reported,
 * so treat it as a hint; the IP always comes from the request.
 */
class DeviceInfo
{
    /** Validation rules for the block under $key. */
    public static function rules(string $key = 'device'): array
    {
        return [
            $key => ['nullable', 'array'],
            "{$key}.id" => ['nullable', 'string', 'max:128'],
            "{$key}.name" => ['nullable', 'string', 'max:120'],
            "{$key}.brand" => ['nullable', 'string', 'max:60'],
            "{$key}.model" => ['nullable', 'string', 'max:120'],
            "{$key}.os_version" => ['nullable', 'string', 'max:60'],
            "{$key}.is_emulator" => ['nullable', 'boolean'],
            "{$key}.details" => ['nullable', 'array', 'max:30'],
        ];
    }

    /** The validated block mapped to the device_* columns. */
    public static function columns(array $device): array
    {
        return [
            'device_id' => $device['id'] ?? null,
            'device_name' => $device['name'] ?? null,
            'device_brand' => $device['brand'] ?? null,
            'device_model' => $device['model'] ?? null,
            'os_version' => $device['os_version'] ?? null,
            'is_emulator' => $device['is_emulator'] ?? null,
            'device_details' => $device['details'] ?? null,
        ];
    }
}
