<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Store;
use App\Support\Enums\ProductStatus;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProductService
{
    /**
     * @param  array<string, mixed>  $data
     * @param  UploadedFile[]  $images
     */
    public function create(Store $store, array $data, array $images = []): Product
    {
        return DB::transaction(function () use ($store, $data, $images) {
            $product = $store->products()->create([
                ...$data,
                'slug' => $this->generateSlug($store, $data['name']),
                'status' => $data['status'] ?? ProductStatus::DRAFT->value,
            ]);

            foreach ($images as $index => $image) {
                $path = $image->store('products', 'public');

                $product->images()->create([
                    'path' => $path,
                    'is_primary' => $index === 0,
                    'sort_order' => $index,
                ]);
            }

            return $product->load('images');
        });
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  UploadedFile[]  $images
     * @param  string[]|null  $existingImageIds  Ordered IDs of existing images to keep; images not listed are deleted.
     */
    public function update(Product $product, array $data, array $images = [], ?array $existingImageIds = null): Product
    {
        return DB::transaction(function () use ($product, $data, $images, $existingImageIds) {
            $product->update($data);

            if ($existingImageIds !== null) {
                $keptImages = $product->images()->whereIn('id', $existingImageIds)->get()->keyBy('id');

                $product->images()->whereNotIn('id', $existingImageIds)->get()->each(function ($image) {
                    Storage::disk('public')->delete($image->path);
                    $image->delete();
                });

                foreach ($existingImageIds as $index => $id) {
                    $keptImages[$id]?->update(['sort_order' => $index, 'is_primary' => $index === 0]);
                }
            }

            $nextSortOrder = $product->images()->max('sort_order');
            $nextSortOrder = $nextSortOrder === null ? 0 : $nextSortOrder + 1;
            $hasPrimary = $product->images()->where('is_primary', true)->exists();

            foreach ($images as $index => $image) {
                $path = $image->store('products', 'public');

                $product->images()->create([
                    'path' => $path,
                    'is_primary' => ! $hasPrimary && $index === 0,
                    'sort_order' => $nextSortOrder + $index,
                ]);
            }

            return $product->load('images');
        });
    }

    private function generateSlug(Store $store, string $name): string
    {
        $base = Str::slug($name);
        $slug = $base;
        $suffix = 1;

        while ($store->products()->where('slug', $slug)->exists()) {
            $slug = "{$base}-{$suffix}";
            $suffix++;
        }

        return $slug;
    }
}
