<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MidtransSetting extends Model
{
    public const MODES = ['sandbox', 'production'];

    protected $fillable = [
        'mode',
        'sandbox_server_key',
        'sandbox_client_key',
        'production_server_key',
        'production_client_key',
    ];

    protected $hidden = ['sandbox_server_key', 'production_server_key'];

    protected function casts(): array
    {
        return [
            'sandbox_server_key' => 'encrypted',
            'production_server_key' => 'encrypted',
        ];
    }

    /**
     * The saved row, or (until an admin saves one) the MIDTRANS_* values from .env
     * placed in the slot of their mode, so local setups keep working unchanged.
     */
    public static function current(): self
    {
        if ($setting = static::query()->first()) {
            return $setting;
        }

        $mode = config('services.midtrans.is_production') ? 'production' : 'sandbox';

        return new static([
            'mode' => $mode,
            "{$mode}_server_key" => config('services.midtrans.server_key'),
            "{$mode}_client_key" => config('services.midtrans.client_key'),
        ]);
    }

    public function isProduction(): bool
    {
        return $this->mode === 'production';
    }

    public function serverKey(): string
    {
        return (string) $this->{"{$this->mode}_server_key"};
    }

    public function clientKey(): string
    {
        return (string) $this->{"{$this->mode}_client_key"};
    }

    /** Admin view: server keys only as a masked hint, never in full. */
    public function toPayload(): array
    {
        $payload = [
            'mode' => $this->mode,
            'from_env' => ! $this->exists,
            'notification_url' => url('/api/v1/payments/midtrans/notification'),
        ];

        foreach (self::MODES as $mode) {
            $serverKey = (string) $this->{"{$mode}_server_key"};
            $payload[$mode] = [
                'client_key' => $this->{"{$mode}_client_key"},
                'server_key_set' => $serverKey !== '',
                'server_key_hint' => $serverKey !== '' ? '••••'.substr($serverKey, -4) : null,
            ];
        }

        return $payload;
    }
}
