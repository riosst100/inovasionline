<?php

namespace Tests\Feature;

use App\Models\Banner;
use App\Models\LaunchPopupSetting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class LaunchPopupTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_off_by_default(): void
    {
        $this->getJson('/api/v1/launch-popup')->assertOk()->assertJsonPath('data.mode', 'off');
    }

    public function test_admob_mode(): void
    {
        LaunchPopupSetting::create(['mode' => 'admob', 'max_per_day' => 2]);

        $this->getJson('/api/v1/launch-popup')
            ->assertOk()
            ->assertJsonPath('data.mode', 'admob')
            ->assertJsonPath('data.max_per_day', 2);
    }

    public function test_image_mode_lists_only_images_in_range_and_active(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-10 03:00:00', 'UTC'));
        LaunchPopupSetting::create(['mode' => 'image']);
        $this->popup('Hari Ini');
        $this->popup('Nonaktif', ['is_active' => false]);
        $this->popup('Besok', ['starts_on' => '2026-11-11']);
        $this->popup('Kemarin', ['ends_on' => '2026-11-09']);

        $this->getJson('/api/v1/launch-popup')
            ->assertJsonPath('data.mode', 'image')
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.name', 'Hari Ini');
    }

    public function test_image_weekdays_are_judged_in_wib(): void
    {
        // Sunday 23:00 UTC is already Monday 06:00 in WIB.
        Carbon::setTestNow(Carbon::parse('2026-11-01 23:00:00', 'UTC'));
        LaunchPopupSetting::create(['mode' => 'image']);
        $this->popup('Senin', ['weekdays' => [1]]);
        $this->popup('Selasa', ['weekdays' => [2]]);

        $this->getJson('/api/v1/launch-popup')
            ->assertJsonPath('data.mode', 'image')
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.name', 'Senin');
    }

    public function test_image_mode_falls_back_to_admob_when_nothing_is_scheduled_today(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-10 03:00:00', 'UTC')); // Tuesday
        LaunchPopupSetting::create(['mode' => 'image']);
        $this->popup('Hanya Senin', ['weekdays' => [1]]);

        $this->getJson('/api/v1/launch-popup')
            ->assertJsonPath('data.mode', 'admob')
            ->assertJsonCount(0, 'data.items');
    }

    public function test_image_mode_without_images_falls_back_to_admob(): void
    {
        LaunchPopupSetting::create(['mode' => 'image']);

        $this->getJson('/api/v1/launch-popup')->assertJsonPath('data.mode', 'admob');
    }

    private function popup(string $name, array $attributes = []): Banner
    {
        return Banner::create($attributes + [
            'name' => $name,
            'image_path' => 'https://example.com/'.$name.'.png',
            'placement' => Banner::PLACEMENT_POPUP,
            'is_active' => true,
            'sort_order' => 1,
        ]);
    }
}
