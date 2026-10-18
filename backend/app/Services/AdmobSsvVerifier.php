<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Checks AdMob rewarded-ad server-side verification (SSV) callbacks.
 * https://developers.google.com/admob/android/ssv
 *
 * Google signs every parameter before `signature` (ECDSA/SHA-256) with a key
 * published at KEYS_URL; `signature` and `key_id` are always the last two.
 */
class AdmobSsvVerifier
{
    public const KEYS_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';

    private const CACHE_KEY = 'admob_ssv_verifier_keys';

    /** @param string $rawQuery the query string exactly as received (not re-encoded or sorted) */
    public function verify(string $rawQuery): bool
    {
        $at = strpos($rawQuery, '&signature=');
        if ($at === false) {
            return false;
        }

        $message = substr($rawQuery, 0, $at);
        parse_str(substr($rawQuery, $at + 1), $tail);
        $signature = $this->base64UrlDecode((string) ($tail['signature'] ?? ''));
        $keyId = (string) ($tail['key_id'] ?? '');
        if ($signature === null || $keyId === '') {
            return false;
        }

        $pem = $this->keys()[$keyId] ?? $this->keys(refresh: true)[$keyId] ?? null;
        if ($pem === null) {
            Log::warning('AdMob SSV: unknown key_id', ['key_id' => $keyId]);

            return false;
        }

        return openssl_verify($message, $signature, $pem, OPENSSL_ALGO_SHA256) === 1;
    }

    /** @return array<string, string> key id => PEM public key */
    private function keys(bool $refresh = false): array
    {
        if ($refresh) {
            Cache::forget(self::CACHE_KEY);
        }

        return Cache::remember(self::CACHE_KEY, now()->addDay(), function () {
            $keys = Http::timeout(10)->get(self::KEYS_URL)->throw()->json('keys', []);

            return collect($keys)->mapWithKeys(fn ($k) => [(string) $k['keyId'] => $k['pem']])->all();
        });
    }

    private function base64UrlDecode(string $value): ?string
    {
        $decoded = base64_decode(strtr($value, '-_', '+/').str_repeat('=', (4 - strlen($value) % 4) % 4), true);

        return $decoded === false || $decoded === '' ? null : $decoded;
    }
}
