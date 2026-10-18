<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdmobSettingTest extends TestCase
{
    use RefreshDatabase;

    private const BANNER = 'ca-app-pub-3940256099942544/6300978111';

    public function test_app_config_is_null_until_ads_are_switched_on(): void
    {
        $this->getJson('/api/v1/admob-config')->assertOk()->assertJsonPath('data', null);
    }

    public function test_admin_saves_settings_and_app_receives_them(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/admob', $this->payload())
            ->assertOk()
            ->assertJsonPath('data.android_banner_id', self::BANNER);

        $this->getJson('/api/admin/admob')->assertOk()->assertJsonPath('data.interstitial_every', 3);

        $this->getJson('/api/v1/admob-config')
            ->assertOk()
            ->assertJsonPath('data.banner.android', self::BANNER)
            ->assertJsonPath('data.banner.ios', null)
            ->assertJsonPath('data.placements.home_banner', true)
            ->assertJsonPath('data.placements.product_detail_banner', false)
            ->assertJsonPath('data.interstitial_enabled', true)
            ->assertJsonPath('data.interstitial_every', 3)
            ->assertJsonPath('data.posts_native_every', 4);
    }

    public function test_rejects_malformed_ad_unit_id(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/admob', $this->payload(['ios_banner_id' => 'ca-app-pub-123~456']))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('ios_banner_id');
    }

    public function test_bonus_cannot_require_an_ad_without_a_rewarded_unit(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/admob', $this->payload(['bonus_requires_ad' => true]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('bonus_requires_ad');
    }

    public function test_settings_require_admin(): void
    {
        $this->putJson('/api/admin/admob', $this->payload())->assertUnauthorized();
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'is_active' => true,
            'android_banner_id' => self::BANNER,
            'ios_banner_id' => null,
            'android_interstitial_id' => 'ca-app-pub-3940256099942544/1033173712',
            'ios_interstitial_id' => null,
            'android_rewarded_id' => null,
            'ios_rewarded_id' => null,
            'home_banner' => true,
            'home_bottom_banner' => true,
            'product_list_banner' => false,
            'product_detail_banner' => false,
            'interstitial_enabled' => true,
            'interstitial_every' => 3,
            'bonus_requires_ad' => false,
            'android_native_id' => null,
            'ios_native_id' => null,
            'posts_native_every' => 4,
        ], $overrides);
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
