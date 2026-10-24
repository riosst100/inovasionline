<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppUpdateSetting extends Model
{
    protected $fillable = ['min_build_number', 'message'];

    protected function casts(): array
    {
        return [
            'min_build_number' => 'integer',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static(['min_build_number' => 0]);
    }

    public function toPayload(): array
    {
        return [
            'min_build_number' => (int) $this->min_build_number,
            'message' => $this->message,
        ];
    }
}
