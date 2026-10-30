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

    public function test_admob_mode_every_day(): void
    {
        LaunchPopupSetting::create(['mode' => 'admob', 'max_per_day' => 2]);

        $this->getJson('/api/v1/launch-popup')
            ->assertOk()
            ->assertJsonPath('data.mode', 'admob')
            ->assertJsonPath('data.max_per_day', 2);
    }

    public function test_weekday_schedule_uses_wib(): void
    {
        // 2026-11-01 is a Sunday in UTC but already Monday 06:00 in WIB.
        Carbon::setTestNow(Carbon::parse('2026-11-01 23:00:00', 'UTC'));
        LaunchPopupSetting::create(['mode' => 'admob', 'weekdays' => [1]]);

        $this->getJson('/api/v1/launch-popup')->assertJsonPath('data.mode', 'admob');

        LaunchPopupSetting::query()->update(['weekdays' => json_encode([2])]);

        $this->getJson('/api/v1/launch-popup')->assertJsonPath('data.mode', 'off');
    }

    public function test_date_range_limits_the_schedule(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-10 03:00:00', 'UTC'));
        LaunchPopupSetting::create(['mode' => 'admob', 'starts_on' => '2026-11-11', 'ends_on' => '2026-11-12']);

        $this->getJson('/api/v1/launch-popup')->assertJsonPath('data.mode', 'off');
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

    public function test_image_mode_without_images_is_off(): void
    {
        LaunchPopupSetting::create(['mode' => 'image']);

        $this->getJson('/api/v1/launch-popup')->assertJsonPath('data.mode', 'off');
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
