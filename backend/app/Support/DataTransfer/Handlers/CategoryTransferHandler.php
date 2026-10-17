<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Category;
use App\Services\CategoryService;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * Rows are matched on `slug` (or on `name` when slug is empty): existing
 * categories are updated, the rest are created. `parent` takes the slug or
 * name of a top-level category.
 */
class CategoryTransferHandler implements TransferHandler
{
    public function __construct(private readonly CategoryService $categoryService) {}

    public function label(): string
    {
        return 'Kategori';
    }

    public function headers(): array
    {
        return ['name', 'slug', 'parent', 'description', 'image_url', 'sort_order', 'is_active'];
    }

    public function sampleRow(): array
    {
        return [
            // Deliberately not a real slug, so importing the untouched template never overwrites data.
            'name' => 'Contoh Kategori',
            'slug' => 'contoh-kategori',
            'parent' => null,
            'description' => 'Hapus baris ini dan isi dengan data Anda',
            'image_url' => null,
            'sort_order' => '1',
            'is_active' => '1',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return Category::query()
            ->with('parent:id,slug')
            ->when($filters['status'] ?? null, function ($query, $status) {
                $query->where('is_active', $status === 'active');
            })
            // Parents first, so the exported file can be re-imported as-is.
            ->orderByRaw('parent_id is not null')
            ->orderBy('sort_order')
            ->orderBy('id');
    }

    public function exportRow(Model $model): array
    {
        /** @var Category $model */
        return [
            'name' => $model->name,
            'slug' => $model->slug,
            'parent' => $model->parent?->slug,
            'description' => $model->description,
            'image_url' => $model->image_path
                ? (str_starts_with($model->image_path, 'http') ? $model->image_path : asset('storage/'.$model->image_path))
                : null,
            'sort_order' => (int) $model->sort_order,
            'is_active' => $model->is_active ? 1 : 0,
        ];
    }

    public function prepareImport(array $rows): array
    {
        // Top-level rows first so children can reference parents created in the same file.
        uasort($rows, fn ($a, $b) => (int) filled($a['parent'] ?? null) <=> (int) filled($b['parent'] ?? null));

        return $rows;
    }

    public function importRow(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        if ($name === '') {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }
        if (mb_strlen($name) > 255) {
            throw new RowSkippedException('Kolom name maksimal 255 karakter.');
        }

        $slug = filled($row['slug'] ?? null) ? Str::slug($row['slug']) : null;
        $category = $slug !== null
            ? Category::query()->where('slug', $slug)->first()
            : Category::query()->whereRaw('lower(name) = ?', [mb_strtolower($name)])->first();

        $data = ['name' => $name];

        if (array_key_exists('parent', $row)) {
            $data['parent_id'] = $this->resolveParent($row['parent'], $category);
        }
        if (array_key_exists('description', $row)) {
            $data['description'] = $row['description'];
        }
        if (filled($row['image_url'] ?? null)) {
            $data['image_path'] = $this->imagePath($row['image_url']);
        }
        if (filled($row['sort_order'] ?? null)) {
            if (! ctype_digit((string) $row['sort_order'])) {
                throw new RowSkippedException('Kolom sort_order harus angka bulat ≥ 0.');
            }
            $data['sort_order'] = (int) $row['sort_order'];
        }
        if (filled($row['is_active'] ?? null)) {
            $data['is_active'] = $this->toBool($row['is_active']);
        }

        if ($category) {
            if ($name !== $category->name && $slug === null) {
                $data['slug'] = $this->categoryService->generateSlug($name, $category->id);
            }
            $category->update($data);

            return ImportResult::UPDATED;
        }

        Category::create([
            'is_active' => true,
            'sort_order' => ((int) Category::query()->max('sort_order')) + 1,
            ...$data,
            'slug' => $this->categoryService->generateSlug($slug ?? $name),
        ]);

        return ImportResult::CREATED;
    }

    private function resolveParent(?string $value, ?Category $category): ?string
    {
        if (blank($value)) {
            return null;
        }

        $parent = Category::query()
            ->where('slug', Str::slug($value))
            ->orWhereRaw('lower(name) = ?', [mb_strtolower(trim($value))])
            ->first();

        if (! $parent) {
            throw new RowSkippedException("Kategori induk \"{$value}\" tidak ditemukan.");
        }
        if ($parent->parent_id !== null) {
            throw new RowSkippedException("Kategori induk \"{$value}\" adalah subkategori; hanya kategori utama yang bisa menjadi induk.");
        }
        if ($category && $parent->id === $category->id) {
            throw new RowSkippedException('Kategori tidak bisa menjadi induk dirinya sendiri.');
        }
        if ($category && $category->children()->exists()) {
            throw new RowSkippedException('Kategori yang memiliki subkategori tidak bisa dijadikan subkategori.');
        }

        return $parent->id;
    }

    /** Store our own exported asset URLs as relative paths; keep external URLs as-is. */
    private function imagePath(string $url): string
    {
        if (! preg_match('#^https?://#i', $url)) {
            throw new RowSkippedException('Kolom image_url harus berupa URL http(s).');
        }

        $local = asset('storage').'/';

        return str_starts_with($url, $local) ? substr($url, strlen($local)) : $url;
    }

    private function toBool(string $value): bool
    {
        return in_array(strtolower(trim($value)), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
    }
}
