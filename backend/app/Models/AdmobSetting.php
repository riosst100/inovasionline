<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AdmobSetting extends Model
{
    protected $fillable = [
        'is_active',
        'android_banner_id',
        'ios_banner_id',
        'android_interstitial_id',
        'ios_interstitial_id',
        'android_rewarded_id',
        'ios_rewarded_id',
        'android_native_id',
        'ios_native_id',
        'home_banner',
        'home_bottom_banner',
        'product_list_banner',
        'product_detail_banner',
        'interstitial_enabled',
        'interstitial_every',
        'bonus_requires_ad',
        'posts_native_every',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'home_banner' => 'boolean',
            'home_bottom_banner' => 'boolean',
            'product_list_banner' => 'boolean',
            'product_detail_banner' => 'boolean',
            'interstitial_enabled' => 'boolean',
            'interstitial_every' => 'integer',
            'bonus_requires_ad' => 'boolean',
            'posts_native_every' => 'integer',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => false,
            'home_banner' => true,
            'home_bottom_banner' => true,
            'product_list_banner' => true,
            'product_detail_banner' => true,
            'interstitial_enabled' => false,
            'interstitial_every' => 5,
            'bonus_requires_ad' => false,
            'posts_native_every' => 6,
        ]);
    }

    /** The bonus is gated only while ads as a whole are on. */
    public function bonusRequiresAd(): bool
    {
        return $this->is_active && $this->bonus_requires_ad;
    }

    /**
     * Whether an SSV callback's ad_unit (the numeric part after the slash) is one
     * of ours. Without this, anyone could point their own AdMob unit at our
     * callback URL and get validly signed views for arbitrary user ids.
     */
    public function isOwnRewardedUnit(string $adUnit): bool
    {
        return $adUnit !== '' && collect([$this->android_rewarded_id, $this->ios_rewarded_id])
            ->filter()
            ->contains(fn (string $id) => str_ends_with($id, '/'.$adUnit));
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'android_banner_id' => $this->android_banner_id,
            'ios_banner_id' => $this->ios_banner_id,
            'android_interstitial_id' => $this->android_interstitial_id,
            'ios_interstitial_id' => $this->ios_interstitial_id,
            'android_rewarded_id' => $this->android_rewarded_id,
            'ios_rewarded_id' => $this->ios_rewarded_id,
            'android_native_id' => $this->android_native_id,
            'ios_native_id' => $this->ios_native_id,
            'home_banner' => (bool) $this->home_banner,
            'home_bottom_banner' => (bool) $this->home_bottom_banner,
            'product_list_banner' => (bool) $this->product_list_banner,
            'product_detail_banner' => (bool) $this->product_detail_banner,
            'interstitial_enabled' => (bool) $this->interstitial_enabled,
            'interstitial_every' => (int) $this->interstitial_every,
            'bonus_requires_ad' => (bool) $this->bonus_requires_ad,
            'posts_native_every' => (int) $this->posts_native_every,
            'ssv_callback_url' => route('admob.ssv'),
        ];
    }

    /** What the app needs; null while ads are off so the app skips the SDK entirely. */
    public function toAppPayload(): ?array
    {
        if (! $this->is_active) {
            return null;
        }

        return [
            'banner' => [
                'android' => $this->android_banner_id,
                'ios' => $this->ios_banner_id,
            ],
            'interstitial' => [
                'android' => $this->android_interstitial_id,
                'ios' => $this->ios_interstitial_id,
            ],
            'rewarded' => [
                'android' => $this->android_rewarded_id,
                'ios' => $this->ios_rewarded_id,
            ],
            'native' => [
                'android' => $this->android_native_id,
                'ios' => $this->ios_native_id,
            ],
            'placements' => [
                'home_banner' => (bool) $this->home_banner,
                'home_bottom_banner' => (bool) $this->home_bottom_banner,
                'product_list_banner' => (bool) $this->product_list_banner,
                'product_detail_banner' => (bool) $this->product_detail_banner,
            ],
            'interstitial_enabled' => (bool) $this->interstitial_enabled,
            'interstitial_every' => max(1, (int) $this->interstitial_every),
            'bonus_requires_ad' => (bool) $this->bonus_requires_ad,
            'posts_native_every' => (int) $this->posts_native_every,
        ];
    }
}
