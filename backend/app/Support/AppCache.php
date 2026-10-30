<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Version numbers for the data the mobile app keeps on the phone (see
 * apps/lib/core/api/response_cache.dart).
 *
 * The app asks `/api/v1/cache-versions` once on start. A group whose version
 * is unchanged is read from the phone without any request; a higher version
 * means refetch. Versions go up by themselves when the models behind a group
 * are saved or deleted, when stock moves, and from Pengaturan > Cache Aplikasi
 * (all groups, or only the ones picked there).
 */
final class AppCache
{
    private const TABLE = 'app_cache_versions';

    private const CACHE_KEY = 'app-cache-versions';

    /**
     * group => label, description, models whose save/delete bumps it, and how
     * long (seconds) the phone may trust its copy even if the version never
     * moves (a safety net against a missed bump).
     *
     * @var array<string, array{label: string, description: string, models: list<class-string>, max_age: int}>
     */
    public const GROUPS = [
        'banners' => [
            'label' => 'Banner & Popup',
            'description' => 'Slider beranda dan popup saat aplikasi dibuka.',
            'models' => [\App\Models\Banner::class, \App\Models\LaunchPopupSetting::class],
            'max_age' => 86400,
        ],
        'categories' => [
            'label' => 'Kategori',
            'description' => 'Daftar kategori produk.',
            'models' => [\App\Models\Category::class],
            'max_age' => 86400,
        ],
        'checkout' => [
            'label' => 'Opsi Checkout',
            'description' => 'Metode pembayaran, metode & tarif pengiriman, jadwal pengiriman, biaya layanan, gratis ongkir.',
            'models' => [
                \App\Models\PaymentMethod::class,
                \App\Models\ShippingMethod::class,
                \App\Models\ShippingMethodRate::class,
                \App\Models\DeliverySchedule::class,
                \App\Models\DeliveryHoliday::class,
                \App\Models\ServiceFeeSetting::class,
                \App\Models\FreeShippingSetting::class,
            ],
            'max_age' => 86400,
        ],
        'regions' => [
            'label' => 'Wilayah & Cakupan',
            'description' => 'Provinsi, kota, kecamatan, dan desa yang bisa dipilih pada alamat.',
            'models' => [\App\Models\ServiceCity::class, \App\Models\ServiceArea::class],
            'max_age' => 86400,
        ],
        'app_config' => [
            'label' => 'Konfigurasi Aplikasi',
            'description' => 'Versi aplikasi, iklan (AdMob), dan badge menu.',
            'models' => [\App\Models\AppUpdateSetting::class, \App\Models\AdmobSetting::class, \App\Models\NavBadgeSetting::class],
            'max_age' => 86400,
        ],
        'products' => [
            'label' => 'Produk, Stok & Flash Sale',
            'description' => 'Produk terlaris, flash sale, detail produk, dan produk per kategori. Naik otomatis saat stok berubah (checkout, pembatalan, atur stok).',
            'models' => [
                \App\Models\Product::class,
                \App\Models\ProductVariant::class,
                \App\Models\ProductImage::class,
                \App\Models\Brand::class,
                \App\Models\Promotion::class,
                \App\Models\PromotionProduct::class,
                \App\Models\FlashSaleSlot::class,
            ],
            // Prices and countdowns move on their own, so trust it for minutes only.
            'max_age' => 600,
        ],
    ];

    /**
     * Current version of every group.
     *
     * @return array<string, int>
     */
    public static function versions(): array
    {
        return Cache::rememberForever(self::CACHE_KEY, function () {
            $rows = DB::table(self::TABLE)->pluck('version', 'group_key');

            return collect(array_keys(self::GROUPS))
                ->mapWithKeys(fn (string $group) => [$group => (int) ($rows[$group] ?? 1)])
                ->all();
        });
    }

    /** @return array<string, int> group => seconds the phone may trust its copy */
    public static function maxAges(): array
    {
        return collect(self::GROUPS)->map(fn (array $g) => $g['max_age'])->all();
    }

    /**
     * Rows for the admin page: label, description, version and when it last moved.
     *
     * @return list<array{key: string, label: string, description: string, version: int, updated_at: ?string}>
     */
    public static function overview(): array
    {
        $rows = DB::table(self::TABLE)->get()->keyBy('group_key');

        return collect(self::GROUPS)->map(fn (array $g, string $key) => [
            'key' => $key,
            'label' => $g['label'],
            'description' => $g['description'],
            'version' => (int) ($rows[$key]->version ?? 1),
            'updated_at' => $rows[$key]->updated_at ?? null,
        ])->values()->all();
    }

    /**
     * Raise the version of one or several groups, so phones fetch them again.
     *
     * @param  string|list<string>  $groups
     */
    public static function bump(string|array $groups): void
    {
        $groups = array_values(array_intersect(array_unique((array) $groups), array_keys(self::GROUPS)));
        if ($groups === []) {
            return;
        }

        $now = now();
        foreach ($groups as $group) {
            DB::table(self::TABLE)->insertOrIgnore(['group_key' => $group, 'version' => 1, 'created_at' => $now, 'updated_at' => $now]);
            DB::table(self::TABLE)->where('group_key', $group)->update(['version' => DB::raw('version + 1'), 'updated_at' => $now]);
        }

        // After commit, so a phone never reads the new number before the data is in place.
        DB::afterCommit(fn () => Cache::forget(self::CACHE_KEY));
    }

    /** Bump a group whenever one of its models is saved or deleted. Called once at boot. */
    public static function listen(): void
    {
        foreach (self::GROUPS as $group => $definition) {
            foreach ($definition['models'] as $model) {
                $model::saved(fn () => self::bump($group));
                $model::deleted(fn () => self::bump($group));
            }
        }
    }
}
