<?php

namespace App\Services;

use App\Models\Category;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

class CategoryService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function createFromSeller(User $seller, array $data): Category
    {
        return Category::create([
            ...$data,
            'slug' => $this->generateSlug($data['name']),
            'is_active' => false,
            'created_by' => $seller->id,
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function createFromAdmin(User $admin, array $data, ?UploadedFile $image = null): Category
    {
        unset($data['image']);

        return Category::create([
            ...$data,
            'slug' => $this->generateSlug($data['name']),
            'is_active' => $data['is_active'] ?? true,
            'sort_order' => $data['sort_order'] ?? ((int) Category::query()->max('sort_order')) + 1,
            'image_path' => $image?->store('categories', 'public'),
            'created_by' => $admin->id,
        ]);
    }

    public function approve(Category $category): Category
    {
        if ($category->is_active) {
            throw new RuntimeException('Category is already active.');
        }

        $category->update(['is_active' => true]);

        return $category->fresh();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Category $category, array $data, ?UploadedFile $image = null): Category
    {
        unset($data['image']);

        if (($data['parent_id'] ?? null) === $category->id) {
            throw new RuntimeException('A category cannot be its own parent category.');
        }

        if (array_key_exists('parent_id', $data) && $data['parent_id'] !== null && $category->children()->exists()) {
            throw new RuntimeException('Cannot turn a category with subcategories into a subcategory.');
        }

        if ($image !== null) {
            if ($category->image_path && ! str_starts_with($category->image_path, 'http')) {
                Storage::disk('public')->delete($category->image_path);
            }
            $data['image_path'] = $image->store('categories', 'public');
        }

        $category->update([
            ...$data,
            'slug' => $data['name'] !== $category->name
                ? $this->generateSlug($data['name'], $category->id)
                : $category->slug,
        ]);

        return $category->fresh();
    }

    private function generateSlug(string $name, ?string $excludeId = null): string
    {
        $base = Str::slug($name);
        $slug = $base;
        $suffix = 1;

        while (Category::where('slug', $slug)->when($excludeId, fn ($query) => $query->where('id', '!=', $excludeId))->exists()) {
            $slug = "{$base}-{$suffix}";
            $suffix++;
        }

        return $slug;
    }
}
