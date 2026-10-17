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
            ['name' => 'Makanan & Minuman', 'slug' => 'makanan-minuman', 'is_active' => true],
            ['name' => 'Sayur Segar', 'slug' => 'sayur-segar', 'is_active' => false],
            ['name' => 'Daging Segar', 'slug' => 'daging-segar', 'is_active' => true],
            ['name' => 'Ikan & Seafood', 'slug' => 'ikan-seafood', 'is_active' => true],
            ['name' => 'Kebutuhan Dapur', 'slug' => 'kebutuhan-dapur', 'is_active' => true],
            ['name' => 'Frozen Food', 'slug' => 'frozen-food', 'is_active' => true],
            ['name' => 'Buah Segar', 'slug' => 'buah-segar', 'is_active' => true],
            ['name' => 'Telur, Tahu & Tempe', 'slug' => 'telur-tahu-tempe', 'is_active' => false],
            ['name' => 'Elektronik', 'slug' => 'elektronik', 'is_active' => false],
            ['name' => 'Percetakan', 'slug' => 'percetakan', 'is_active' => true],
            ['name' => 'Alat Tulis Kantor', 'slug' => 'alat-tulis-kantor', 'is_active' => true],
            ['name' => 'Hadiah & Kado', 'slug' => 'hadiah-kado', 'is_active' => true],
            ['name' => 'Perlengkapan Pesta', 'slug' => 'perlengkapan-pesta', 'is_active' => true],
            ['name' => 'Tanaman & Bunga', 'slug' => 'tanaman-bunga', 'is_active' => false],
            ['name' => 'Hewan Peliharaan', 'slug' => 'hewan-peliharaan', 'is_active' => true],
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
                    'image_path' => $imagePath,
                    'sort_order' => $index + 1,
                    'is_active' => $data['is_active'],
                ]
            );
        }
    }
}
