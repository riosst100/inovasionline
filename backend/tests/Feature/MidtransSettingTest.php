<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\MidtransSetting;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MidtransSettingTest extends TestCase
{
    use RefreshDatabase;

    public function test_falls_back_to_env_until_saved(): void
    {
        config([
            'services.midtrans.server_key' => 'SB-Mid-server-env1234',
            'services.midtrans.is_production' => false,
        ]);
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->getJson('/api/admin/midtrans-settings')
            ->assertOk()
            ->assertJsonPath('data.mode', 'sandbox')
            ->assertJsonPath('data.from_env', true)
            ->assertJsonPath('data.sandbox.server_key_hint', '••••1234')
            ->assertJsonMissing(['SB-Mid-server-env1234']);

        $this->assertSame('SB-Mid-server-env1234', MidtransSetting::current()->serverKey());
    }

    public function test_admin_switches_to_production_and_keeps_sandbox_key(): void
    {
        config(['services.midtrans.server_key' => 'SB-Mid-server-env1234']);
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/midtrans-settings', [
            'mode' => 'production',
            'production' => ['client_key' => 'Mid-client-abc', 'server_key' => 'Mid-server-prod9876'],
        ])
            ->assertOk()
            ->assertJsonPath('data.mode', 'production')
            ->assertJsonPath('data.from_env', false)
            ->assertJsonPath('data.production.server_key_hint', '••••9876')
            ->assertJsonPath('data.sandbox.server_key_set', true);

        $setting = MidtransSetting::current();
        $this->assertTrue($setting->isProduction());
        $this->assertSame('Mid-server-prod9876', $setting->serverKey());
        // Stored encrypted.
        $this->assertStringNotContainsString('prod9876', (string) DB::table('midtrans_settings')->value('production_server_key'));

        // A blank server key keeps the stored one.
        $this->putJson('/api/admin/midtrans-settings', ['mode' => 'sandbox', 'production' => ['server_key' => '']])
            ->assertOk();
        $this->assertSame('SB-Mid-server-env1234', MidtransSetting::current()->serverKey());
        $this->assertSame('Mid-server-prod9876', MidtransSetting::current()->production_server_key);
    }

    public function test_rejects_sandbox_key_in_production_and_missing_active_key(): void
    {
        config(['services.midtrans.server_key' => null]);
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/midtrans-settings', [
            'mode' => 'production',
            'production' => ['server_key' => 'SB-Mid-server-oops'],
        ])->assertUnprocessable()->assertJsonValidationErrors('production.server_key');

        $this->putJson('/api/admin/midtrans-settings', ['mode' => 'production'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('production.server_key');
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
