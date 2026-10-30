<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Banner;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BannerPlacementTest extends TestCase
{
    use RefreshDatabase;

    public function test_slider_is_the_default_and_excludes_popups(): void
    {
        $this->banner('Slider A', Banner::PLACEMENT_SLIDER);
        $this->banner('Popup A', Banner::PLACEMENT_POPUP);

        $this->getJson('/api/v1/banners')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Slider A');
    }

    public function test_popup_placement_returns_only_active_popups(): void
    {
        $this->banner('Slider A', Banner::PLACEMENT_SLIDER);
        $this->banner('Popup A', Banner::PLACEMENT_POPUP);
        $this->banner('Popup Off', Banner::PLACEMENT_POPUP, isActive: false);

        $this->getJson('/api/v1/banners?placement=popup')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Popup A')
            ->assertJsonPath('data.0.placement', 'popup');
    }

    public function test_admin_creates_popup_banner(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->postJson('/api/admin/banners', [
            'name' => 'Promo Akhir Bulan',
            'image_url' => 'https://example.com/promo.jpg',
            'placement' => 'popup',
        ])->assertCreated()->assertJsonPath('data.placement', 'popup');

        $this->postJson('/api/admin/banners', [
            'name' => 'Salah',
            'image_url' => 'https://example.com/x.jpg',
            'placement' => 'sidebar',
        ])->assertUnprocessable()->assertJsonValidationErrors('placement');
    }

    private function banner(string $name, string $placement, bool $isActive = true): Banner
    {
        return Banner::create([
            'name' => $name,
            'image_path' => 'https://example.com/'.$name.'.jpg',
            'placement' => $placement,
            'is_active' => $isActive,
            'sort_order' => 1,
        ]);
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
