<?php

namespace App\Services;

use App\Models\User;
use App\Support\Enums\UserRole;
use Google\Client as GoogleClient;
use Illuminate\Auth\Events\Registered;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

class AuthService
{
    public function __construct(private readonly ChatService $chatService) {}

    public function register(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'] ?? null,
                'phone' => $data['phone'],
                'gender' => $data['gender'] ?? null,
                'date_of_birth' => $data['date_of_birth'] ?? null,
                'password' => Hash::make($data['password']),
                'role' => UserRole::CUSTOMER,
                'province_code' => $data['province_code'] ?? null,
                'city_code' => $data['city_code'] ?? null,
                'district_code' => $data['district_code'] ?? null,
                'village_code' => $data['village_code'] ?? null,
            ]);

            $this->chatService->syncMembershipsForUser($user);

            event(new Registered($user));

            return $user;
        });
    }

    public function loginWithGoogle(string $idToken): User
    {
        $payload = $this->verifyGoogleIdToken($idToken);

        return DB::transaction(function () use ($payload) {
            $user = User::where('google_id', $payload['sub'])->first();

            if ($user) {
                return $user;
            }

            $user = User::where('email', $payload['email'])->first();

            if ($user) {
                $user->update(['google_id' => $payload['sub']]);

                return $user;
            }

            $user = User::create([
                'name' => $payload['name'] ?? $payload['email'],
                'email' => $payload['email'],
                'google_id' => $payload['sub'],
                'password' => null,
                'role' => UserRole::CUSTOMER,
                'email_verified_at' => now(),
            ]);

            $this->chatService->syncMembershipsForUser($user);

            event(new Registered($user));

            return $user;
        });
    }

    private function verifyGoogleIdToken(string $idToken): array
    {
        $client = new GoogleClient(['client_id' => config('services.google.client_id')]);
        $payload = $client->verifyIdToken($idToken);

        if (! $payload || empty($payload['email'])) {
            throw new RuntimeException('Invalid Google token.');
        }

        return $payload;
    }
}
