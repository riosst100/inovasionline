<?php

namespace Database\Seeders;

use App\Models\Warehouse;
use Illuminate\Database\Seeder;

class WarehouseSeeder extends Seeder
{
    public function run(): void
    {
        $warehouses = [
            [
                'code' => 'IO-TLD',
                'name' => 'Tiwulandu Main Warehouse',
                'address' => 'Desa Tiwulandu RT 02 RW 01, Jl Denah Asih',
                'city' => 'Brebes',
                'province' => 'Jawa Tengah',
                'postal_code' => '52265',
                'latitude' => -6.170325,
                'longitude' => 106.816017,
                'contact_name' => 'Rio',
                'contact_phone' => '081385461740',
            ],
            [
                'code' => 'IO-BJH',
                'name' => 'Banjarharjo Warehouse',
                'address' => 'Desa Banjarharjo RT 14 RW 02, Jl Pramuka',
                'city' => 'Brebes',
                'province' => 'Jawa Tengah',
                'postal_code' => '52265',
                'latitude' => -6.1703249,
                'longitude' => 106.8160167,
                'contact_name' => 'Mala',
                'contact_phone' => '081385461740',
            ],
        ];

        foreach ($warehouses as $data) {
            Warehouse::updateOrCreate(['code' => $data['code']], $data + ['is_active' => true]);
        }
    }
}
