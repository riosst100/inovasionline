<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\AppInstall;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AppUpdateSettingTest extends TestCase
{
    use RefreshDatabase;

    public function test_app_gets_no_forced_update_by_default(): void
    {
        $this->getJson('/api/v1/app-version')
            ->assertOk()
            ->assertJsonPath('data.min_build_number', 0)
            ->assertJsonPath('data.message', null);
    }

    public function test_admin_sets_minimum_build_and_app_receives_it(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/app-update', [
            'min_build_number' => 125,
            'message' => 'Ada perbaikan bug pembayaran.',
        ])->assertOk()->assertJsonPath('data.min_build_number', 125);

        $this->getJson('/api/v1/app-version')
            ->assertOk()
            ->assertJsonPath('data.min_build_number', 125)
            ->assertJsonPath('data.message', 'Ada perbaikan bug pembayaran.');
    }

    public function test_admin_sees_active_android_installs_per_build(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        foreach ([124, 124, 120] as $build) {
            $this->heartbeat(['build_number' => $build]);
        }
        $this->heartbeat(['platform' => 'ios', 'build_number' => 124]);
        AppInstall::query()->create([
            'install_id' => str_repeat('s', 20),
            'platform' => 'android',
            'app_version' => '1.0.0',
            'build_number' => 100,
            'first_seen_at' => now()->subDays(90),
            'last_seen_at' => now()->subDays(60),
        ]);

        $this->getJson('/api/admin/app-update')
            ->assertOk()
            ->assertJsonPath('data.builds', [
                ['build_number' => 124, 'version' => '1.0.1', 'installs' => 2],
                ['build_number' => 120, 'version' => '1.0.1', 'installs' => 1],
            ]);
    }

    public function test_rejects_negative_minimum(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/app-update', ['min_build_number' => -1])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('min_build_number');
    }

    public function test_settings_require_admin(): void
    {
        $this->putJson('/api/admin/app-update', ['min_build_number' => 1])->assertUnauthorized();
    }

    private function heartbeat(array $overrides = []): void
    {
        $this->postJson('/api/v1/app/heartbeat', array_merge([
            'install_id' => bin2hex(random_bytes(10)),
            'platform' => 'android',
            'app_version' => '1.0.1',
        ], $overrides))->assertOk();
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
