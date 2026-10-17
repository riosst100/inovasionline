<?php

namespace Database\Seeders;

use App\Models\Banner;
use App\Models\Category;
use App\Models\FlashSaleSlot;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\Promotion;
use App\Models\User;
use App\Models\Warehouse;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use App\Support\Enums\PromotionType;
use App\Support\Enums\UserRole;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class CatalogSeeder extends Seeder
{
    public function run(): void
    {
        // 2. Seed Categories (data & images from CategorySeeder)
        $this->call(CategorySeeder::class);
        $categories = Category::query()->get()->keyBy('slug')->all();

        // 3. Seed Products
        $productsData = [
            [
                'category' => 'makanan-minuman',
                'name' => 'Dimsum',
                'slug' => 'dimsum',
                'sku' => 'DIMSUM',
                'regular_price' => 1000,
                'sale_price' => null,
                'stock' => 100,
                'image' => 'dimsum',
            ],
            [
                'category' => 'makanan-minuman',
                'name' => 'Dimsum Goreng',
                'slug' => 'dimsum-goreng',
                'sku' => 'DIMSUM-GORENG',
                'regular_price' => 16000,
                'sale_price' => null,
                'stock' => 100,
                'image' => 'dimsum-goreng',
            ],
        ];

        $warehouse = Warehouse::where('code', 'IO-TLD')->first();
        $disk = Storage::disk('public');

        $createdProducts = [];
        foreach ($productsData as $prod) {
            $cat = $categories[$prod['category']] ?? null;
            $product = Product::updateOrCreate(
                ['slug' => $prod['slug']],
                [
                    'category_id' => $cat?->id,
                    'name' => $prod['name'],
                    'product_type' => ProductType::PHYSICAL,
                    'sku' => $prod['sku'],
                    'regular_price' => $prod['regular_price'],
                    'sale_price' => $prod['sale_price'],
                    'status' => ProductStatus::ACTIVE,
                ]
            );

            $source = database_path("seeders/assets/products/{$prod['image']}.png");
            if (is_file($source)) {
                $imagePath = "products/{$prod['image']}.png";
                $disk->put($imagePath, file_get_contents($source));

                ProductImage::updateOrCreate(
                    ['product_id' => $product->id, 'is_primary' => true],
                    [
                        'path' => $imagePath,
                        'alt_text' => $prod['name'],
                        'sort_order' => 1,
                    ]
                );
            }

            if ($warehouse) {
                $product->warehouses()->syncWithoutDetaching([
                    $warehouse->id => ['quantity' => $prod['stock']],
                ]);
            }

            $createdProducts[] = $product;
        }

        // 4. Seed an active Flash Sale with a fixed price per product
        $flashSale = Promotion::updateOrCreate(
            ['code' => 'FLASH-GERCEP'],
            [
                'name' => 'Promo Gercep',
                'type' => PromotionType::FLASH_SALE,
                'starts_at' => now('Asia/Jakarta')->startOfDay()->utc(),
                'ends_at' => now('Asia/Jakarta')->endOfDay()->utc(),
                'is_active' => true,
            ]
        );

        $flashProducts = array_slice($createdProducts, 0, 6);
        $flashSale->products()->sync(collect($flashProducts)->mapWithKeys(function ($fp, $index) {
            $discountPct = [20, 25, 15, 30, 22, 18][$index % 6];

            return [$fp->id => ['flash_sale_price' => round((float) $fp->regular_price * (100 - $discountPct) / 100)]];
        })->all());

        // 5. Seed Banners
        $bannersData = [
            [
                'name' => 'Gratis Ongkir Cepat Sampai 15 Menit',
                'image_path' => 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1000&auto=format&fit=crop&q=80',
                'sort_order' => 1,
            ],
            [
                'name' => 'Promo Segar Pilihan Terbaik Hari Ini',
                'image_path' => 'https://images.unsplash.com/photo-1579113800032-c38bd7635818?w=1000&auto=format&fit=crop&q=80',
                'sort_order' => 2,
            ],
            [
                'name' => 'Daging Wagyu & Steak Kualitas Premium',
                'image_path' => 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1000&auto=format&fit=crop&q=80',
                'sort_order' => 3,
            ],
        ];

        foreach ($bannersData as $b) {
            Banner::updateOrCreate(
                ['name' => $b['name']],
                [
                    'image_path' => $b['image_path'],
                    'sort_order' => $b['sort_order'],
                    'is_active' => true,
                ]
            );
        }
    }
}
