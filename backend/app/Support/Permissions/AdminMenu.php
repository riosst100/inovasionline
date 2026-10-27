<?php

namespace App\Support\Permissions;

/**
 * Admin panel menus a role can be granted, mirroring the sidebar of frontend-admin
 * (components/layout/AdminSidebar.tsx). Each menu yields the permissions `{key}.view`
 * (open the page / read its data) and, when it has anything to change, `{key}.manage`
 * (create / update / delete). Manage implies view.
 *
 * API routes are guarded per menu with the `menu` middleware (EnsureMenuPermission).
 * When you add a sidebar menu, add it here, guard its routes and set `perm` on the
 * sidebar item.
 */
final class AdminMenu
{
    /** Permissions that are not a sidebar menu. */
    public const EXTRAS = [
        'delivery.update' => 'Aplikasi Kurir: scan paket & update status pengiriman',
        'notifications.broadcast' => 'Kirim broadcast notifikasi',
    ];

    /**
     * Sidebar section => menus. A menu is [key, label, sidebar group or null, has manage].
     *
     * @return array<string, list<array{0: string, 1: string, 2: ?string, 3: bool}>>
     */
    public static function sections(): array
    {
        return [
            'Utama' => [
                ['dashboard', 'Ringkasan Dashboard', null, false],
                ['orders', 'Pesanan', null, true],
                ['delivery_schedules', 'Jadwal Pengiriman', null, true],
                ['cod_verifications', 'Verifikasi Pengguna', null, true],
            ],
            'Operasional' => [
                ['customers', 'Pengguna', null, true],
                ['notifications', 'Kirim Notifikasi', null, true],
                ['wallets', 'Saldo Pengguna', 'Saldo Belanja', true],
                ['wallet_topups', 'Top Up Saldo', 'Saldo Belanja', false],
                ['products', 'Produk', 'Master Data', true],
                ['categories', 'Kategori', 'Master Data', true],
                ['attributes', 'Atribut Produk', 'Master Data', true],
                ['suppliers', 'Supplier', 'Master Data', true],
                ['brands', 'Brand', 'Master Data', true],
                ['warehouses', 'Gudang', 'Master Data', true],
                ['drivers', 'Kurir', 'Master Data', true],
                ['product_stocks', 'Stok Produk', 'Laporan', true],
                ['search_suggestions', 'Kueri Pencarian', 'Laporan', true],
                ['wallet_report', 'Laporan Saldo Belanja', 'Laporan', false],
                ['banners', 'Banner', 'Tampilan', true],
                ['vouchers', 'Voucher', 'Promosi', true],
                ['discounts', 'Diskon', 'Promosi', true],
                ['flash_sales', 'Flash Sale', 'Promosi', true],
                ['free_shipping', 'Gratis Ongkir', 'Promosi', true],
                ['wallet_bonus', 'Bonus Saldo Belanja', 'Promosi', true],
                ['product_ads', 'Iklan Produk', 'Iklan', true],
                ['admob', 'Adsense / Admob', 'Iklan', true],
                ['reward_chest', 'Peti Hadiah', 'Iklan', true],
                ['service_cities', 'Cakupan Kota', 'Pengaturan', true],
                ['service_fee', 'Biaya Layanan', 'Pengaturan', true],
                ['payment_gateway', 'Payment Gateway (Midtrans)', 'Pengaturan', true],
                ['nav_badge', 'Badge Menu', 'Pengaturan', true],
                ['app_update', 'Update Aplikasi', 'Pengaturan', true],
                ['order_statuses', 'Status Pesanan', 'Pengaturan', true],
                ['shipping_methods', 'Metode Pengiriman', 'Pengaturan', true],
                ['order_cancellation', 'Pembatalan Pesanan', 'Pengaturan', true],
            ],
            'Perusahaan' => [
                ['employees', 'Karyawan', null, true],
                ['purchases', 'Pembelian', null, true],
                ['cashflow', 'Cashflow', 'Keuangan', true],
                ['finance_report', 'Laporan Keuangan', 'Keuangan', false],
            ],
            'Admin' => [
                ['users', 'User', null, true],
                ['roles', 'Hak Akses & Role', null, true],
            ],
            'Data' => [
                ['data_transfers', 'Import / Export', null, true],
            ],
        ];
    }

    /** Shape served to the role editor. */
    public static function catalog(): array
    {
        $sections = [];
        foreach (self::sections() as $title => $menus) {
            $sections[] = [
                'title' => $title,
                'menus' => array_map(fn (array $m) => [
                    'key' => $m[0],
                    'label' => $m[1],
                    'group' => $m[2],
                    'manage' => $m[3],
                ], $menus),
            ];
        }

        $extras = [];
        foreach (self::EXTRAS as $key => $label) {
            $extras[] = ['key' => $key, 'label' => $label];
        }

        return ['sections' => $sections, 'extras' => $extras];
    }

    /** Every grantable permission key. */
    public static function permissionKeys(): array
    {
        $keys = array_keys(self::EXTRAS);
        foreach (self::sections() as $menus) {
            foreach ($menus as [$key, , , $manage]) {
                $keys[] = "{$key}.view";
                if ($manage) {
                    $keys[] = "{$key}.manage";
                }
            }
        }

        return $keys;
    }

    /** @param  \App\Models\AdminUser|\App\Models\User  $user */
    public static function canView($user, string $menu): bool
    {
        return $user->hasPermission("{$menu}.view") || $user->hasPermission("{$menu}.manage");
    }

    /** @param  \App\Models\AdminUser|\App\Models\User  $user */
    public static function canManage($user, string $menu): bool
    {
        return $user->hasPermission("{$menu}.manage");
    }
}
