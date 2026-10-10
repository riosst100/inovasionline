<?php

namespace App\Services;

use App\Models\Seller;
use App\Models\SellerApplication;
use App\Models\Store;
use App\Models\User;
use App\Support\Enums\SellerApplicationStatus;
use App\Support\Enums\StoreStatus;
use App\Support\Enums\UserRole;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class SellerApplicationService
{
    public function apply(User $user, array $data): SellerApplication
    {
        if ($user->seller) {
            throw new RuntimeException('You are already a registered seller.');
        }

        if ($user->sellerApplications()->where('status', SellerApplicationStatus::PENDING)->exists()) {
            throw new RuntimeException('You already have a pending seller application.');
        }

        return DB::transaction(function () use ($user, $data) {
            return $user->sellerApplications()->create([
                ...$data,
                'store_slug' => $this->generateStoreSlug($data['store_name']),
                'status' => SellerApplicationStatus::PENDING,
            ]);
        });
    }

    public function approve(SellerApplication $application, User $admin): SellerApplication
    {
        if ($application->status !== SellerApplicationStatus::PENDING) {
            throw new RuntimeException('Only pending applications can be approved.');
        }

        return DB::transaction(function () use ($application, $admin) {
            $application->update([
                'status' => SellerApplicationStatus::APPROVED,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
            ]);

            $seller = Seller::create([
                'user_id' => $application->user_id,
                'seller_application_id' => $application->id,
                'status' => SellerApplicationStatus::APPROVED,
            ]);

            Store::create([
                'seller_id' => $seller->id,
                'category_id' => $application->main_category_id,
                'name' => $application->store_name,
                'slug' => $application->store_slug,
                'description' => $application->business_description,
                'business_type' => $application->business_type,
                'logo_path' => $application->logo_path,
                'cover_path' => $application->cover_path,
                'phone' => $application->phone,
                'email' => $application->email,
                'address' => $application->address,
                'province' => $application->province,
                'city' => $application->city,
                'district' => $application->district,
                'postal_code' => $application->postal_code,
                'latitude' => $application->latitude,
                'longitude' => $application->longitude,
                'status' => StoreStatus::OPEN,
                'approved_at' => now(),
            ]);

            $application->user->update(['role' => UserRole::SELLER_OWNER]);

            return $application->fresh();
        });
    }

    public function reject(SellerApplication $application, User $admin, string $reason): SellerApplication
    {
        if ($application->status !== SellerApplicationStatus::PENDING) {
            throw new RuntimeException('Only pending applications can be rejected.');
        }

        $application->update([
            'status' => SellerApplicationStatus::REJECTED,
            'rejection_reason' => $reason,
            'reviewed_by' => $admin->id,
            'reviewed_at' => now(),
        ]);

        return $application->fresh();
    }

    private function generateStoreSlug(string $storeName): string
    {
        $base = Str::slug($storeName);
        $slug = $base;
        $suffix = 1;

        while (SellerApplication::where('store_slug', $slug)->exists()) {
            $slug = "{$base}-{$suffix}";
            $suffix++;
        }

        return $slug;
    }
}
