<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\AppInstall;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCustomerLastSeenTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_heartbeat_links_the_logged_in_user(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('app')->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/app/heartbeat', [
            'install_id' => str_repeat('a', 20),
            'platform' => 'android',
        ])->assertOk();

        $this->assertSame($user->id, AppInstall::sole()->user_id);
    }

    public function test_last_seen_is_the_latest_of_heartbeat_and_api_use(): void
    {
        [$appUser, $apiUser, $never] = User::factory()->count(3)->create();

        AppInstall::create([
            'install_id' => str_repeat('b', 20), 'platform' => 'android', 'user_id' => $appUser->id,
            'first_seen_at' => '2026-10-01 00:00:00', 'last_seen_at' => '2026-10-20 08:00:00',
        ]);
        $appUser->createToken('app')->accessToken->forceFill(['last_used_at' => '2026-10-19 08:00:00'])->save();
        $apiUser->createToken('app')->accessToken->forceFill(['last_used_at' => '2026-10-21 09:30:00'])->save();

        Sanctum::actingAs($this->admin(), ['admin']);
        $rows = collect($this->getJson('/api/admin/customers?per_page=50')->assertOk()->json('data'))->keyBy('id');

        $this->assertSame('2026-10-20T08:00:00', substr($rows[$appUser->id]['last_seen_at'], 0, 19));
        $this->assertSame('2026-10-21T09:30:00', substr($rows[$apiUser->id]['last_seen_at'], 0, 19));
        $this->assertNull($rows[$never->id]['last_seen_at']);

        $this->getJson("/api/admin/customers/{$apiUser->id}")
            ->assertOk()
            ->assertJsonPath('data.customer.last_seen_at', fn ($v) => str_starts_with($v, '2026-10-21T09:30:00'));
    }

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super-admin', 'is_system' => true])->id,
        ]);
    }
}
