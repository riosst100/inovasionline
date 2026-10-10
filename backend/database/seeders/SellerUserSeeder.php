<?php

namespace Database\Seeders;

use App\Models\Seller;
use App\Models\SellerApplication;
use App\Models\Store;
use App\Models\StoreMember;
use App\Models\User;
use App\Support\Enums\SellerApplicationStatus;
use App\Support\Enums\StoreStatus;
use App\Support\Enums\UserRole;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class SellerUserSeeder extends Seeder
{
    /**
     * Seed a sample seller account with an approved store.
     *
     * Credentials can be overridden via SELLER_EMAIL / SELLER_PASSWORD env vars.
     */
    public function run(): void
    {
        $email = env('SELLER_EMAIL', 'seller@gmail.com');
        $password = env('SELLER_PASSWORD', 'password');

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => 'Sample Seller',
                'phone' => null,
                'password' => Hash::make($password),
                'role' => UserRole::SELLER_OWNER,
                'email_verified_at' => now(),
            ]
        );

        $application = SellerApplication::updateOrCreate(
            ['user_id' => $user->id],
            [
                'full_name' => $user->name,
                'email' => $user->email,
                'phone' => '081234567890',
                'store_name' => 'Sample Store',
                'store_slug' => 'sample-store',
                'business_type' => 'individual',
                'business_description' => 'Sample seller account for testing.',
                'address' => 'Jl. Contoh No. 1',
                'province' => 'DKI Jakarta',
                'city' => 'Jakarta Selatan',
                'status' => SellerApplicationStatus::APPROVED,
                'reviewed_at' => now(),
            ]
        );

        $seller = Seller::updateOrCreate(
            ['user_id' => $user->id],
            [
                'seller_application_id' => $application->id,
                'status' => SellerApplicationStatus::APPROVED,
            ]
        );

        $store = Store::updateOrCreate(
            ['slug' => 'sample-store'],
            [
                'seller_id' => $seller->id,
                'name' => 'Sample Store',
                'description' => 'Sample store seeded for testing.',
                'business_type' => 'individual',
                'address' => 'Jl. Contoh No. 1',
                'province' => 'DKI Jakarta',
                'city' => 'Jakarta Selatan',
                'status' => StoreStatus::OPEN,
                'approved_at' => now(),
            ]
        );

        StoreMember::updateOrCreate(
            ['store_id' => $store->id, 'user_id' => $user->id],
            ['role' => 'owner']
        );

        $this->command?->info("Seller user ready: {$user->email}");
    }
}
