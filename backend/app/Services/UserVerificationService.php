<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserVerification;
use App\Support\Enums\UserVerificationStatus;
use Illuminate\Http\UploadedFile;
use RuntimeException;

class UserVerificationService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function submit(User $user, array $data, UploadedFile $selfie, UploadedFile $document): UserVerification
    {
        if ($user->isVerified()) {
            throw new RuntimeException('You are already verified.');
        }

        if ($user->userVerifications()->where('status', UserVerificationStatus::PENDING)->exists()) {
            throw new RuntimeException('You already have a pending verification submission.');
        }

        return $user->userVerifications()->create([
            ...$data,
            'selfie_path' => $selfie->store('verifications/selfies', 'public'),
            'document_path' => $document->store('verifications/documents', 'public'),
            'status' => UserVerificationStatus::PENDING,
        ]);
    }

    public function approve(UserVerification $verification, User $admin): UserVerification
    {
        if ($verification->status !== UserVerificationStatus::PENDING) {
            throw new RuntimeException('Only pending verifications can be approved.');
        }

        $verification->update([
            'status' => UserVerificationStatus::APPROVED,
            'reviewed_by' => $admin->id,
            'reviewed_at' => now(),
        ]);

        return $verification->fresh();
    }

    public function reject(UserVerification $verification, User $admin, string $reason): UserVerification
    {
        if ($verification->status !== UserVerificationStatus::PENDING) {
            throw new RuntimeException('Only pending verifications can be rejected.');
        }

        $verification->update([
            'status' => UserVerificationStatus::REJECTED,
            'rejection_reason' => $reason,
            'reviewed_by' => $admin->id,
            'reviewed_at' => now(),
        ]);

        return $verification->fresh();
    }
}
