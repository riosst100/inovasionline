<?php

namespace App\Support;

class PhoneNumber
{
    /**
     * Normalize an Indonesian phone number to international format
     * (leading 0 becomes 62), stripping any non-digit characters.
     */
    public static function normalize(?string $phone): ?string
    {
        if ($phone === null) {
            return null;
        }

        $digits = preg_replace('/\D/', '', $phone);

        if (str_starts_with($digits, '0')) {
            $digits = '62'.substr($digits, 1);
        }

        return $digits;
    }
}
