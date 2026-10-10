<?php

namespace App\Services;

use App\Models\PhoneOtp;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class WhatsAppOtpService
{
    public function send(string $phone): void
    {
        $code = (string) random_int(100000, 999999);

        PhoneOtp::where('phone', $phone)->delete();

        PhoneOtp::create([
            'phone' => $phone,
            'code' => $code,
            'expires_at' => now()->addMinutes(5),
        ]);

        $message = "*{$code}* adalah kode verifikasi Anda untuk Inovasi Online. Jangan bagikan kode ini ke siapapun. Berlaku 5 menit.";

        $response = Http::withHeaders([
            'X-Api-Key' => config('services.whatsapp_otp.api_key'),
        ])
            ->timeout(15)
            ->post(config('services.whatsapp_otp.base_url').'/send', [
                'phone' => $phone,
                'message' => $message,
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Failed to send WhatsApp OTP: '.$response->body());
        }
    }

    public function verify(string $phone, string $code): bool
    {
        $otp = PhoneOtp::where('phone', $phone)->first();

        if (! $otp || $otp->expires_at->isPast()) {
            return false;
        }

        if ($otp->attempts >= 5) {
            return false;
        }

        if (! hash_equals($otp->code, $code)) {
            $otp->increment('attempts');

            return false;
        }

        // Keep the row around (instead of deleting it) so a subsequent step
        // in the registration flow can confirm this phone was verified,
        // without asking the user to re-enter the code.
        $otp->update(['verified_at' => now()]);

        return true;
    }

    /**
     * True if this phone number completed OTP verification within the last
     * 15 minutes, e.g. to gate a later step of a multi-step registration
     * flow without requiring the user to re-verify.
     */
    public function isRecentlyVerified(string $phone): bool
    {
        return PhoneOtp::where('phone', $phone)
            ->whereNotNull('verified_at')
            ->where('verified_at', '>=', now()->subMinutes(15))
            ->exists();
    }

    public function clearVerification(string $phone): void
    {
        PhoneOtp::where('phone', $phone)->delete();
    }
}
