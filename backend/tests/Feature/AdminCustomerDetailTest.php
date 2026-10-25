<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCustomerDetailTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_records_history_and_token_ip(): void
    {
        $user = User::factory()->create(['email' => 'cust@example.com', 'password' => 'secret123']);

        $this->withHeaders(['X-Client' => 'mobile', 'User-Agent' => 'Dart/3.5 (dart:io)'])
            ->withServerVariables(['REMOTE_ADDR' => '10.1.2.3'])
            ->postJson('/api/v1/auth/login', ['login' => 'cust@example.com', 'password' => 'secret123', 'device_name' => 'Android 14'])
            ->assertOk();

        $this->assertDatabaseHas('user_login_logs', [
            'user_id' => $user->id,
            'method' => 'password',
            'client' => 'mobile',
            'device_name' => 'Android 14',
            'ip_address' => '10.1.2.3',
        ]);
        $this->assertDatabaseHas('personal_access_tokens', [
            'tokenable_id' => $user->id,
            'name' => 'Android 14',
            'ip_address' => '10.1.2.3',
        ]);
    }

    public function test_admin_sees_customer_detail_with_sessions_devices_and_ips(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('Android 14');
        $token->accessToken->forceFill(['ip_address' => '10.0.0.9', 'user_agent' => 'Dart/3.5'])->save();
        $user->loginLogs()->create(['method' => 'google', 'client' => 'mobile', 'device_name' => 'Android 14', 'ip_address' => '10.0.0.9']);
        $user->loginLogs()->create(['method' => 'password', 'client' => 'web', 'device_name' => 'Chrome · Windows', 'ip_address' => '10.0.0.1']);
        $user->deviceTokens()->create(['token' => str_repeat('a', 40), 'platform' => 'android']);

        Sanctum::actingAs($this->admin(), ['admin']);

        $res = $this->getJson("/api/admin/customers/{$user->id}")->assertOk();

        $res->assertJsonPath('data.customer.id', $user->id)
            ->assertJsonPath('data.login.login_count', 2)
            ->assertJsonPath('data.login.active_session_count', 1)
            ->assertJsonCount(1, 'data.sessions')
            ->assertJsonPath('data.sessions.0.ip_address', '10.0.0.9')
            ->assertJsonCount(1, 'data.push_devices')
            ->assertJsonPath('data.push_devices.0.platform', 'android')
            ->assertJsonCount(2, 'data.ip_addresses')
            ->assertJsonCount(2, 'data.login_history');

        $ip = collect($res->json('data.ip_addresses'))->firstWhere('ip_address', '10.0.0.9');
        $this->assertSame(1, $ip['login_count']);
        $this->assertSame(1, $ip['active_sessions']);
        $this->assertStringNotContainsString(str_repeat('a', 40), $res->getContent());
    }

    public function test_admin_can_revoke_customer_session(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('Android 14')->accessToken;

        Sanctum::actingAs($this->admin(), ['admin']);

        $this->deleteJson("/api/admin/customers/{$user->id}/sessions/{$token->id}")->assertOk();
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token->id]);
        $this->deleteJson("/api/admin/customers/{$user->id}/sessions/{$token->id}")->assertNotFound();
    }

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super_admin', 'is_system' => true])->id,
        ]);
    }
}
