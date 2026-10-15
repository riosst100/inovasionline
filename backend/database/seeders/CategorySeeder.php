<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            ['name' => 'Makanan & Minuman', 'slug' => 'makanan-minuman', 'icon' => '🧊', 'is_active' => true],
            ['name' => 'Sayur Segar', 'slug' => 'sayur-segar', 'icon' => '🥦', 'is_active' => true],
            ['name' => 'Daging Segar', 'slug' => 'daging-segar', 'icon' => '🥩', 'is_active' => true],
            ['name' => 'Seafood Segar', 'slug' => 'seafood-segar', 'icon' => '🦐', 'is_active' => false],
            ['name' => 'Kebutuhan Dapur', 'slug' => 'kebutuhan-dapur', 'icon' => '🧂', 'is_active' => true],
            ['name' => 'Frozen Food', 'slug' => 'frozen-food', 'icon' => null, 'is_active' => true],
            ['name' => 'Buah Segar', 'slug' => 'buah-segar', 'icon' => '🥭', 'is_active' => true],
            ['name' => 'Telur, Tahu & Tempe', 'slug' => 'telur-tahu-tempe', 'icon' => '🥚', 'is_active' => true],
            ['name' => 'Elektronik', 'slug' => 'elektronik', 'icon' => null, 'is_active' => true],
        ];

        $disk = Storage::disk('public');

        foreach ($categories as $index => $data) {
            $source = database_path("seeders/assets/categories/{$data['slug']}.png");
            $imagePath = null;

            if (is_file($source)) {
                $imagePath = "categories/{$data['slug']}.png";
                $disk->put($imagePath, file_get_contents($source));
            }

            Category::updateOrCreate(
                ['slug' => $data['slug']],
                [
                    'name' => $data['name'],
                    'icon' => $data['icon'],
                    'image_path' => $imagePath,
                    'sort_order' => $index + 1,
                    'is_active' => $data['is_active'],
                ]
            );
        }
    }
}
