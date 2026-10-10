<?php

namespace App\Services;

use App\Models\Photographer;
use App\Models\PhotographerApplication;
use App\Models\User;
use App\Support\Enums\PhotographerApplicationStatus;
use App\Support\Enums\UserRole;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PhotographerApplicationService
{
    public function apply(User $user, array $data): PhotographerApplication
    {
        if ($user->photographer) {
            throw new RuntimeException('You are already an approved photographer.');
        }

        if ($user->photographerApplications()->where('status', PhotographerApplicationStatus::PENDING)->exists()) {
            throw new RuntimeException('You already have a pending photographer application.');
        }

        return DB::transaction(function () use ($user, $data) {
            return $user->photographerApplications()->create([
                ...$data,
                'status' => PhotographerApplicationStatus::PENDING,
            ]);
        });
    }

    public function approve(PhotographerApplication $application, User $admin): PhotographerApplication
    {
        if ($application->status !== PhotographerApplicationStatus::PENDING) {
            throw new RuntimeException('Only pending applications can be approved.');
        }

        return DB::transaction(function () use ($application, $admin) {
            $application->update([
                'status' => PhotographerApplicationStatus::APPROVED,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
            ]);

            Photographer::create([
                'user_id' => $application->user_id,
                'photographer_application_id' => $application->id,
                'status' => PhotographerApplicationStatus::APPROVED,
                'display_name' => $application->business_name ?: $application->full_name,
            ]);

            $application->user->update(['role' => UserRole::PHOTOGRAPHER]);

            return $application->fresh();
        });
    }

    public function reject(PhotographerApplication $application, User $admin, string $reason): PhotographerApplication
    {
        if ($application->status !== PhotographerApplicationStatus::PENDING) {
            throw new RuntimeException('Only pending applications can be rejected.');
        }

        $application->update([
            'status' => PhotographerApplicationStatus::REJECTED,
            'rejection_reason' => $reason,
            'reviewed_by' => $admin->id,
            'reviewed_at' => now(),
        ]);

        return $application->fresh();
    }
}
