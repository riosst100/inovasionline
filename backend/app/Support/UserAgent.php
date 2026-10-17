<?php

namespace App\Support;

class UserAgent
{
    /** Human readable "Browser · OS" label from a User-Agent string. */
    public static function label(?string $ua): string
    {
        $ua = (string) $ua;

        if (str_starts_with($ua, 'Dart/')) {
            return 'Aplikasi Mobile';
        }

        $browser = match (true) {
            str_contains($ua, 'Edg/') => 'Edge',
            str_contains($ua, 'OPR/') || str_contains($ua, 'Opera') => 'Opera',
            str_contains($ua, 'Firefox/') => 'Firefox',
            str_contains($ua, 'Chrome/') => 'Chrome',
            str_contains($ua, 'Safari/') => 'Safari',
            default => 'Browser',
        };

        $os = match (true) {
            str_contains($ua, 'Windows') => 'Windows',
            str_contains($ua, 'Android') => 'Android',
            str_contains($ua, 'iPhone') || str_contains($ua, 'iPad') => 'iOS',
            str_contains($ua, 'Mac OS') => 'macOS',
            str_contains($ua, 'Linux') => 'Linux',
            default => 'Unknown OS',
        };

        return "{$browser} · {$os}";
    }
}
