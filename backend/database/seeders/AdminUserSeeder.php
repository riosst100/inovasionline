<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminUserSeeder extends Seeder
{
    /**
     * Seed default roles, super admin, and sample drivers with orders.
     */
    public function run(): void
    {
        // 1. Seed Default Roles
        $superAdminRole = Role::updateOrCreate(
            ['slug' => 'super_admin'],
            [
                'name' => 'Super Admin',
                'description' => 'Akses penuh tanpa batas ke seluruh modul sistem dan manajemen role.',
                'permissions' => ['*'],
                'is_system' => true,
            ]
        );

        Role::updateOrCreate(
            ['slug' => 'admin'],
            [
                'name' => 'Admin',
                'description' => 'Pengelolaan operasional harian, katalog produk, pesanan, dan banner.',
                'permissions' => [
                    'dashboard.view',
                    'users.view',
                    'orders.view',
                    'orders.manage',
                    ...self::viewAndManage(['products', 'categories', 'attributes', 'suppliers', 'brands', 'warehouses', 'product_stocks', 'banners']),
                ],
                'is_system' => true,
            ]
        );

        Role::updateOrCreate(
            ['slug' => 'sales'],
            [
                'name' => 'Sales',
                'description' => 'Operasional promosi, monitor pesanan pembeli, dan follow-up transaksi.',
                'permissions' => [
                    'dashboard.view',
                    'orders.view',
                    'orders.manage',
                    'products.view',
                    'categories.view',
                    ...self::viewAndManage(['vouchers', 'discounts', 'flash_sales', 'free_shipping', 'wallet_bonus']),
                ],
                'is_system' => false,
            ]
        );

        $driverRole = Role::updateOrCreate(
            ['slug' => 'driver'],
            [
                'name' => 'Kurir',
                'description' => 'Petugas kurir pengantaran barang dan update status ekspedisi pengiriman.',
                'permissions' => [
                    'orders.view',
                    'delivery.update',
                ],
                'is_system' => false,
            ]
        );

        // 2. Seed Default Super Admin
        $email = env('ADMIN_EMAIL', 'admin@inovasionline.com');
        $password = env('ADMIN_PASSWORD', 'password');

        $adminUser = AdminUser::updateOrCreate(
            ['email' => $email],
            [
                'name' => 'Super Admin',
                'phone' => '081122334455',
                'password' => Hash::make($password),
                'role_id' => $superAdminRole->id,
                'is_active' => true,
            ]
        );

        // 3. Seed Sample Drivers
        $driver1 = AdminUser::updateOrCreate(
            ['email' => 'budi.driver@inovasionline.com'],
            [
                'name' => 'Budi Santoso',
                'phone' => '081234567890',
                'password' => Hash::make('password'),
                'role_id' => $driverRole->id,
                'vehicle_type' => 'Motor Honda Vario 160',
                'vehicle_plate_number' => 'B 4521 TKL',
                'is_active' => true,
            ]
        );

        $driver2 = AdminUser::updateOrCreate(
            ['email' => 'rahmat.driver@inovasionline.com'],
            [
                'name' => 'Rahmat Hidayat',
                'phone' => '082198765432',
                'password' => Hash::make('password'),
                'role_id' => $driverRole->id,
                'vehicle_type' => 'Mobil Daihatsu GranMax',
                'vehicle_plate_number' => 'B 8912 PQR',
                'is_active' => true,
            ]
        );

        // 4. Seed Sample Orders assigned to Driver 1
        $customer = User::first();

        if ($customer && Order::where('driver_id', $driver1->id)->count() === 0) {
            Order::create([
                'order_number' => 'ORD-' . strtoupper(Str::random(8)),
                'user_id' => $customer->id,
                'driver_id' => $driver1->id,
                'subtotal' => 125000,
                'discount_total' => 10000,
                'shipping_fee' => 15000,
                'tax_total' => 0,
                'grand_total' => 130000,
                'status' => OrderStatus::PROCESSING,
                'payment_status' => PaymentStatus::PAID,
                'delivery_method' => 'Kurir Kilat Inovasi',
                'delivery_address' => [
                    'address_line' => 'Jl. Kebon Jeruk No. 45, Jakarta Barat',
                    'city' => 'Jakarta Barat',
                    'notes' => 'Pagar warna hitam, titip satpam bila tidak ada orang',
                ],
            ]);

            Order::create([
                'order_number' => 'ORD-' . strtoupper(Str::random(8)),
                'user_id' => $customer->id,
                'driver_id' => $driver1->id,
                'subtotal' => 85000,
                'discount_total' => 0,
                'shipping_fee' => 10000,
                'tax_total' => 0,
                'grand_total' => 95000,
                'status' => OrderStatus::COMPLETED,
                'payment_status' => PaymentStatus::PAID,
                'delivery_method' => 'Kurir Reguler',
                'delivery_address' => [
                    'address_line' => 'Komplek Permata Hijau Blok C3/12, Jakarta Selatan',
                    'city' => 'Jakarta Selatan',
                ],
                'completed_at' => now()->subHours(2),
            ]);
        }

        $this->command?->info("Default roles, Super Admin, and drivers seeded successfully.");
    }

    /** View + manage permissions for admin menus (see AdminMenu). */
    private static function viewAndManage(array $menus): array
    {
        return collect($menus)->flatMap(fn ($m) => ["{$m}.view", "{$m}.manage"])->all();
    }
}
