<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Roles used to hold module permissions (catalog.manage, settings.manage, ...) that nothing
     * enforced. Access is now per admin menu ({menu}.view / {menu}.manage, see AdminMenu), so
     * translate each old key into the menus it covered. Keys already in the new format stay.
     */
    public function up(): void
    {
        $catalog = ['products', 'categories', 'attributes', 'suppliers', 'brands', 'warehouses', 'product_stocks'];
        $promotions = ['vouchers', 'discounts', 'flash_sales', 'free_shipping', 'wallet_bonus'];
        $settings = ['service_cities', 'service_fee', 'nav_badge', 'app_update', 'order_statuses', 'shipping_methods', 'order_cancellation'];

        $view = fn (array $menus) => array_map(fn ($m) => "{$m}.view", $menus);
        $manage = fn (array $menus) => [...$view($menus), ...array_map(fn ($m) => "{$m}.manage", $menus)];

        $map = [
            'users.manage' => $manage(['users']),
            'roles.manage' => $manage(['roles']),
            'catalog.view' => $view($catalog),
            'catalog.manage' => $manage($catalog),
            'orders.manage' => $manage(['orders']),
            'delivery.view' => $view(['delivery_schedules']),
            'banners.manage' => $manage(['banners']),
            'flash_sale.manage' => $manage(['flash_sales']),
            'promotions.manage' => $manage($promotions),
            'settings.manage' => $manage($settings),
        ];

        DB::table('roles')->orderBy('id')->each(function ($role) use ($map) {
            $old = json_decode($role->permissions ?? '[]', true) ?: [];
            $new = [];
            foreach ($old as $key) {
                array_push($new, ...($map[$key] ?? [$key]));
            }

            DB::table('roles')->where('id', $role->id)->update([
                'permissions' => json_encode(array_values(array_unique($new))),
            ]);
        });
    }

    public function down(): void
    {
        // One-way: the old module keys were never enforced, so there is nothing to restore.
    }
};
