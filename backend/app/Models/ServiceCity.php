<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceCity extends Model
{
    protected $fillable = ['city_code'];

    /**
     * City codes served by the app, or null when none are configured yet
     * (callers then fall back to their built-in defaults).
     *
     * @return list<string>|null
     */
    public static function activeCodes(): ?array
    {
        $codes = static::query()->pluck('city_code')->map(fn ($c) => trim($c))->all();

        return $codes === [] ? null : $codes;
    }
}
