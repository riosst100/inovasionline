<?php

namespace App\Services;

use App\Models\CodVerification;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * The user's status lives on users.verification_status / verification_id; cod_verifications
 * is the event log. Every status change goes through here so both stay in step.
 */
class CodVerificationService
{
    /** Every step the app's liveness flow must report. */
    public const REQUIRED_STEPS = ['come_closer', 'turn_right', 'turn_left', 'nod', 'blink', 'color_check'];

    public function current(User $user): ?CodVerification
    {
        return $user->verification_status === CodVerification::STATUS_VERIFIED ? $user->verification : null;
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

        $path = $video->store('cod-verifications', 'public');

        return DB::transaction(function () use ($user, $path, $steps, $device, $ip) {
            $verification = $user->codVerifications()->create([
                'video_path' => $path,
                'steps' => array_values($steps),
                'device' => $device,
                'ip_address' => $ip,
                'status' => CodVerification::STATUS_VERIFIED,
            ]);

            $user->forceFill([
                'verification_status' => CodVerification::STATUS_VERIFIED,
                'verification_id' => $verification->id,
            ])->save();

            return $verification;
        });
    }

    /**
     * Revoke on a specific event. After revoking, the customer must verify again before the
     * next COD or Paylater order; the user's status points at this event so it's clear why.
     */
    public function revoke(CodVerification $verification, string $reason): CodVerification
    {
        if ($verification->status === CodVerification::STATUS_REVOKED) {
            throw new RuntimeException('Verifikasi ini sudah dicabut.');
        }

        DB::transaction(function () use ($verification, $reason) {
            $verification->update([
                'status' => CodVerification::STATUS_REVOKED,
                'revoked_reason' => $reason,
                'revoked_at' => now(),
            ]);

            $verification->user->forceFill([
                'verification_status' => CodVerification::STATUS_REVOKED,
                'verification_id' => $verification->id,
            ])->save();
        });

        return $verification->fresh();
    }

    /** Revoke from the customer list: revokes the event that currently verifies the user. */
    public function revokeUser(User $user, string $reason): CodVerification
    {
        $verification = $this->current($user) ?? throw new RuntimeException('Customer ini belum terverifikasi.');

        return $this->revoke($verification, $reason);
    }
}
