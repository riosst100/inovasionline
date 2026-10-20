<?php

namespace App\Services;

use App\Models\CodVerification;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use RuntimeException;

class CodVerificationService
{
    /** Every step the app's liveness flow must report. */
    public const REQUIRED_STEPS = ['come_closer', 'turn_right', 'turn_left', 'nod', 'blink', 'color_check'];

    public function current(User $user): ?CodVerification
    {
        return $user->codVerifications()
            ->where('status', CodVerification::STATUS_VERIFIED)
            ->latest()
            ->first();
    }

    /**
     * @param  list<string>  $steps
     */
    public function submit(User $user, UploadedFile $video, array $steps, ?string $device, ?string $ip): CodVerification
    {
        if ($this->current($user)) {
            throw new RuntimeException('Anda sudah terverifikasi.');
        }

        if (array_diff(self::REQUIRED_STEPS, $steps) !== []) {
            throw new RuntimeException('Semua langkah verifikasi wajah harus diselesaikan.');
        }

        return $user->codVerifications()->create([
            'video_path' => $video->store('cod-verifications', 'public'),
            'steps' => array_values($steps),
            'device' => $device,
            'ip_address' => $ip,
            'status' => CodVerification::STATUS_VERIFIED,
        ]);
    }

    /** After revoking, the customer must verify again before the next COD or Paylater order. */
    public function revoke(CodVerification $verification, string $reason): CodVerification
    {
        if ($verification->status === CodVerification::STATUS_REVOKED) {
            throw new RuntimeException('Verifikasi ini sudah dicabut.');
        }

        $verification->update([
            'status' => CodVerification::STATUS_REVOKED,
            'revoked_reason' => $reason,
            'revoked_at' => now(),
        ]);

        return $verification->fresh();
    }
}
