<?php

namespace Database\Seeders;

use App\Models\User;
use App\Support\Enums\UserRole;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Seed the platform's super admin account.
     *
     * Credentials can be overridden via ADMIN_EMAIL / ADMIN_PASSWORD env vars.
     */
    public function run(): void
    {
        $email = env('ADMIN_EMAIL', 'admin@inovasionline.com');
        $password = env('ADMIN_PASSWORD', 'password');

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => 'Super Admin',
                'phone' => null,
                'password' => Hash::make($password),
                'role' => UserRole::PLATFORM_ADMIN,
                'email_verified_at' => now(),
            ]
        );

        $this->command?->info("Admin user ready: {$user->email}");
    }
}
