<?php

namespace Database\Seeders;

use App\Models\Banner;
use App\Models\Category;
use App\Models\FlashSaleSlot;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\Promotion;
use App\Models\Store;
use App\Models\User;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use App\Support\Enums\PromotionType;
use App\Support\Enums\StoreStatus;
use App\Support\Enums\UserRole;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class CatalogSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Ensure a Store exists
        $store = Store::first();
        if (! $store) {
            $this->call(SellerUserSeeder::class);
            $store = Store::first();
        }

        // 2. Seed Categories (data & images from CategorySeeder)
        $this->call(CategorySeeder::class);
        $categories = Category::query()->get()->keyBy('slug')->all();

        // 3. Seed Products
        $productsData = [
            // Daging & Unggas
            [
                'category' => 'daging-segar',
                'name' => 'Daging Picanha Wagyu Steak MB5+ 150g',
                'slug' => 'daging-picanha-wagyu-steak-mb5-150g',
                'short_description' => 'Daging sapi Wagyu cut Picanha kualitas MB5+ empuk dan juicy.',
                'regular_price' => 130000,
                'sale_price' => null,
                'stock' => 50,
                'image' => 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'daging-segar',
                'name' => 'Karubi Wagyu Beef Slice AUS Meatboy 250g',
                'slug' => 'karubi-wagyu-beef-slice-aus-meatboy-250g',
                'short_description' => 'Slice wagyu short plate Karubi impor Australia cocok untuk shabu & yakiniku.',
                'regular_price' => 119600,
                'sale_price' => 115700,
                'stock' => 45,
                'image' => 'https://images.unsplash.com/photo-1558030006-450675393462?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'daging-segar',
                'name' => 'Sirloin Angus MB3+ Steak AUS Meatboy 200g',
                'slug' => 'sirloin-angus-mb3-steak-aus-meatboy-200g',
                'short_description' => 'Steak Sirloin Black Angus Australia dengan marbling MB3+.',
                'regular_price' => 140000,
                'sale_price' => null,
                'stock' => 30,
                'image' => 'https://images.unsplash.com/photo-1600891964599-f61ba0e24092?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'daging-segar',
                'name' => 'Dada Ayam Fillet Segar Tanpa Tulang 500g',
                'slug' => 'dada-ayam-fillet-segar-500g',
                'short_description' => 'Dada ayam segar higienis tanpa lemak dan kulit, tinggi protein.',
                'regular_price' => 38500,
                'sale_price' => null,
                'stock' => 80,
                'image' => 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=600&auto=format&fit=crop&q=80',
            ],

            // Kebutuhan Dapur
            [
                'category' => 'kebutuhan-dapur',
                'name' => 'Tropical Minyak Goreng Botol 2 Liter',
                'slug' => 'tropical-minyak-goreng-botol-2-liter',
                'short_description' => 'Minyak goreng kelapa sawit 2x penyaringan jernih dan sehat.',
                'regular_price' => 48000,
                'sale_price' => null,
                'stock' => 100,
                'image' => 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'kebutuhan-dapur',
                'name' => 'Sedaap Minyak Goreng Pouch 2 Liter',
                'slug' => 'sedaap-minyak-goreng-pouch-2-liter',
                'short_description' => 'Minyak goreng kelapa sawit pouch berkualitas tinggi renyah maksimal.',
                'regular_price' => 69200,
                'sale_price' => 63000,
                'stock' => 90,
                'image' => 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'kebutuhan-dapur',
                'name' => 'Beras Premium Ramos Wangi Pulen 5kg',
                'slug' => 'beras-premium-ramos-wangi-pulen-5kg',
                'short_description' => 'Beras putih kualitas premium bebas pemutih dan wangi alami.',
                'regular_price' => 74000,
                'sale_price' => null,
                'stock' => 120,
                'image' => 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop&q=80',
            ],

            // Buah Segar
            [
                'category' => 'buah-segar',
                'name' => 'Buah Mangga Harum Manis Super 1kg',
                'slug' => 'buah-mangga-harum-manis-super-1kg',
                'short_description' => 'Mangga Harum Manis matang pohon, daging manis tebal dan harum.',
                'regular_price' => 41000,
                'sale_price' => 35000,
                'stock' => 60,
                'image' => 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'buah-segar',
                'name' => 'Pisang Cavendish Sunpride 1 Sisir',
                'slug' => 'pisang-cavendish-sunpride-1-sisir',
                'short_description' => 'Pisang Cavendish segar manis kaya serat dan potassium.',
                'regular_price' => 24000,
                'sale_price' => null,
                'stock' => 70,
                'image' => 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'buah-segar',
                'name' => 'Apel Fuji Segar Manis Renyah 1kg',
                'slug' => 'apel-fuji-segar-manis-renyah-1kg',
                'short_description' => 'Apel Fuji impor manis berair dan renyah sempurna.',
                'regular_price' => 38000,
                'sale_price' => null,
                'stock' => 65,
                'image' => 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600&auto=format&fit=crop&q=80',
            ],

            // Sayur Segar
            [
                'category' => 'sayur-segar',
                'name' => 'Brokoli Hijau Segar Pilihan 500g',
                'slug' => 'brokoli-hijau-segar-pilihan-500g',
                'short_description' => 'Brokoli hijau segar panen harian bebas pestisida berlebih.',
                'regular_price' => 16500,
                'sale_price' => null,
                'stock' => 55,
                'image' => 'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'sayur-segar',
                'name' => 'Wortel Berastagi Manis Segar 500g',
                'slug' => 'wortel-berastagi-manis-segar-500g',
                'short_description' => 'Wortel Berastagi renyah manis kaya vitamin A.',
                'regular_price' => 12000,
                'sale_price' => null,
                'stock' => 75,
                'image' => 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=600&auto=format&fit=crop&q=80',
            ],

            // Susu & Telur
            [
                'category' => 'susu-olahan-susu',
                'name' => 'Greenfields Fresh Milk UHT Full Cream 1 Liter',
                'slug' => 'greenfields-fresh-milk-uht-full-cream-1l',
                'short_description' => 'Susu segar murni 100% sapi pilihan dari peternakan Greenfields.',
                'regular_price' => 29900,
                'sale_price' => null,
                'stock' => 95,
                'image' => 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'telur-tahu-tempe',
                'name' => 'Telur Ayam Negeri Segar Pilihan 10 Butir',
                'slug' => 'telur-ayam-negeri-segar-pilihan-10-butir',
                'short_description' => 'Telur ayam negeri fresh higienis bebas Salmonella.',
                'regular_price' => 28500,
                'sale_price' => null,
                'stock' => 110,
                'image' => 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=600&auto=format&fit=crop&q=80',
            ],

            // Seafood
            [
                'category' => 'seafood-segar',
                'name' => 'Udang Vaname Kupas Segar Bersih 250g',
                'slug' => 'udang-vaname-kupas-segar-bersih-250g',
                'short_description' => 'Udang laut Vaname segar sudah dikupas dan dibersihkan.',
                'regular_price' => 36000,
                'sale_price' => null,
                'stock' => 40,
                'image' => 'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'seafood-segar',
                'name' => 'Salmon Fillet Norwegia Segar Premium 200g',
                'slug' => 'salmon-fillet-norwegia-segar-premium-200g',
                'short_description' => 'Ikan Salmon Norwegia segar kaya omega-3 cocok untuk sashimi & pan-sear.',
                'regular_price' => 65000,
                'sale_price' => null,
                'stock' => 35,
                'image' => 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=600&auto=format&fit=crop&q=80',
            ],

            // Snack & Minuman
            [
                'category' => 'snack-biskuit',
                'name' => 'Oreo Biskuit Sandwich Vanilla Roll 119g',
                'slug' => 'oreo-biskuit-sandwich-vanilla-roll-119g',
                'short_description' => 'Biskuit cokelat renyah dengan krim vanila lezat.',
                'regular_price' => 9500,
                'sale_price' => 7200,
                'stock' => 150,
                'image' => 'https://images.unsplash.com/photo-1582293041079-7814c2f12063?w=600&auto=format&fit=crop&q=80',
            ],
            [
                'category' => 'minuman',
                'name' => 'Aqua Air Mineral Galon 19 Liter (Isi Ulang)',
                'slug' => 'aqua-air-mineral-galon-19-liter',
                'short_description' => 'Air mineral pegunungan alami murni kemasan galon 19 liter.',
                'regular_price' => 22000,
                'sale_price' => null,
                'stock' => 85,
                'image' => 'https://images.unsplash.com/photo-1523362628745-0c100150b504?w=600&auto=format&fit=crop&q=80',
            ],

            // Perawatan Rumah
            [
                'category' => 'perawatan-rumah',
                'name' => 'Stella Air Freshener Electric Refill Jasmine',
                'slug' => 'stella-air-freshener-electric-refill-jasmine',
                'short_description' => 'Pengharum ruangan elektrik aroma melati segar tahan hingga 60 hari.',
                'regular_price' => 19200,
                'sale_price' => 15000,
                'stock' => 60,
                'image' => 'https://images.unsplash.com/photo-1585751119414-ef2636f8aede?w=600&auto=format&fit=crop&q=80',
            ],
        ];

        $createdProducts = [];
        foreach ($productsData as $prod) {
            $cat = $categories[$prod['category']] ?? null;
            $product = Product::updateOrCreate(
                ['slug' => $prod['slug']],
                [
                    'store_id' => $store->id,
                    'category_id' => $cat?->id,
                    'name' => $prod['name'],
                    'short_description' => $prod['short_description'],
                    'description' => $prod['short_description'] . "\n\nKualitas terjamin, pengiriman instan cepat sampai.",
                    'product_type' => ProductType::PHYSICAL,
                    'regular_price' => $prod['regular_price'],
                    'sale_price' => $prod['sale_price'],
                    'stock' => $prod['stock'],
                    'status' => ProductStatus::ACTIVE,
                    'view_count' => rand(50, 500),
                ]
            );

            ProductImage::updateOrCreate(
                ['product_id' => $product->id, 'is_primary' => true],
                [
                    'path' => $prod['image'],
                    'alt_text' => $prod['name'],
                    'sort_order' => 0,
                ]
            );

            $createdProducts[] = $product;
        }

        // 4. Seed Flash Sale Slot & Active Promotion
        $flashSlot = FlashSaleSlot::updateOrCreate(
            ['label' => 'Promo Gercep 15 Menit'],
            [
                'start_time' => '00:00:00',
                'end_time' => '23:59:59',
                'is_active' => true,
                'sort_order' => 1,
            ]
        );

        $flashProducts = array_slice($createdProducts, 0, 6);
        foreach ($flashProducts as $index => $fp) {
            $discountPct = [20, 25, 15, 30, 22, 18][$index % 6];
            $promo = Promotion::updateOrCreate(
                ['code' => 'FLASH-' . $fp->slug],
                [
                    'store_id' => $store->id,
                    'flash_sale_slot_id' => $flashSlot->id,
                    'name' => 'Promo Gercep ' . $fp->name,
                    'type' => PromotionType::PERCENTAGE_DISCOUNT,
                    'discount_value' => $discountPct,
                    'starts_at' => now()->startOfDay(),
                    'ends_at' => now()->endOfDay(),
                    'is_active' => true,
                ]
            );

            $promo->products()->syncWithoutDetaching([$fp->id]);
        }

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
