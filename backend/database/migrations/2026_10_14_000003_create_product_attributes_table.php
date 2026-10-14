<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_attributes', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('code', 60)->unique();
            $table->string('name', 100);
            $table->string('type', 20)->default('text');
            $table->json('options')->nullable();
            $table->string('description')->nullable();
            $table->boolean('is_system')->default(false);
            $table->boolean('is_required')->default(false);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        // [code, name, type, required]
        $system = [
            ['name', 'Nama Produk', 'text', true],
            ['slug', 'Slug', 'text', true],
            ['sku', 'SKU', 'text', false],
            ['short_description', 'Deskripsi Singkat', 'text', false],
            ['description', 'Deskripsi', 'textarea', false],
            ['category_id', 'Kategori', 'select', false],
            ['product_type', 'Tipe Produk', 'select', true],
            ['regular_price', 'Harga Normal', 'number', true],
            ['sale_price', 'Harga Promo', 'number', false],
            ['cost_price', 'Harga Modal', 'number', false],
            ['stock', 'Stok', 'number', true],
            ['min_stock', 'Stok Minimum', 'number', false],
            ['weight', 'Berat (kg)', 'number', false],
            ['length', 'Panjang (cm)', 'number', false],
            ['width', 'Lebar (cm)', 'number', false],
            ['height', 'Tinggi (cm)', 'number', false],
            ['status', 'Status', 'select', true],
            ['is_taxable', 'Kena Pajak', 'boolean', false],
            ['track_inventory', 'Lacak Inventori', 'boolean', false],
            ['requires_shipping', 'Perlu Pengiriman', 'boolean', false],
            ['available_start_at', 'Mulai Tersedia', 'date', false],
            ['available_end_at', 'Akhir Tersedia', 'date', false],
            ['meta_title', 'Meta Title', 'text', false],
            ['meta_description', 'Meta Description', 'text', false],
        ];

        $now = now();
        DB::table('product_attributes')->insert(array_map(fn ($a, $i) => [
            'id' => (string) Str::ulid(),
            'code' => $a[0],
            'name' => $a[1],
            'type' => $a[2],
            'is_system' => true,
            'is_required' => $a[3],
            'is_active' => true,
            'sort_order' => $i + 1,
            'created_at' => $now,
            'updated_at' => $now,
        ], $system, array_keys($system)));
    }

    public function down(): void
    {
        Schema::dropIfExists('product_attributes');
    }
};
