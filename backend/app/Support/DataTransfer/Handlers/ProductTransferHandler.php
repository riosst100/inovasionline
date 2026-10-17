<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Category;
use App\Models\Product;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * Product master data only. Rows are matched on `id`, then `sku`; unmatched
 * rows create a product. Stock is not part of this file — it has its own
 * import/export (ProductStockTransferHandler). Images are managed in the
 * product form.
 */
class ProductTransferHandler implements TransferHandler
{
    private const DECIMALS = ['regular_price', 'sale_price', 'cost_price', 'weight', 'length', 'width', 'height'];

    public function label(): string
    {
        return 'Produk';
    }

    public function headers(): array
    {
        return [
            'id', 'sku', 'name', 'category', 'product_type', 'status',
            'regular_price', 'sale_price', 'cost_price',
            'short_description', 'description',
            'weight', 'length', 'width', 'height', 'min_stock',
        ];
    }

    public function sampleRow(): array
    {
        return [
            'sku' => 'CONTOH-001',
            'name' => 'Contoh Produk',
            'category' => Category::query()->whereNull('parent_id')->orderBy('sort_order')->value('slug'),
            'product_type' => ProductType::PHYSICAL->value,
            'status' => ProductStatus::DRAFT->value,
            'regular_price' => '15000',
            'short_description' => 'Hapus baris ini dan isi dengan data Anda',
            'weight' => '500',
            'min_stock' => '0',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        $search = trim((string) ($filters['search'] ?? ''));

        return Product::query()
            ->with('category:id,slug')
            ->when($search !== '', fn ($q) => $q->where('name', 'ilike', "%{$search}%"))
            ->when(ProductStatus::tryFrom((string) ($filters['status'] ?? '')), fn ($q, $s) => $q->where('status', $s))
            ->orderBy('name')
            ->orderBy('id');
    }

    public function exportRow(Model $model): array
    {
        /** @var Product $model */
        $row = [
            'id' => $model->id,
            'sku' => $model->sku,
            'name' => $model->name,
            'category' => $model->category?->slug,
            'product_type' => $model->product_type?->value,
            'status' => $model->status?->value,
            'short_description' => $model->short_description,
            'description' => $model->description,
            'min_stock' => (int) $model->min_stock,
        ];
        foreach (self::DECIMALS as $field) {
            $row[$field] = $model->{$field} !== null ? (float) $model->{$field} : null;
        }

        return $row;
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $product = $this->findProduct($row);

        $name = trim((string) ($row['name'] ?? ''));
        if ($name === '' && ! $product) {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }

        $data = $name !== '' ? ['name' => Str::limit($name, 255, '')] : [];

        if (filled($row['sku'] ?? null)) {
            $sku = trim($row['sku']);
            if (mb_strlen($sku) > 100) {
                throw new RowSkippedException('Kolom sku maksimal 100 karakter.');
            }
            if (Product::query()->where('sku', $sku)->when($product, fn ($q) => $q->whereKeyNot($product->id))->exists()) {
                throw new RowSkippedException("SKU \"{$sku}\" sudah dipakai produk lain.");
            }
            $data['sku'] = $sku;
        }

        if (array_key_exists('category', $row)) {
            $data['category_id'] = $this->resolveCategory($row['category']);
        }
        if (filled($row['product_type'] ?? null)) {
            $data['product_type'] = ProductType::tryFrom(strtolower($row['product_type']))
                ?? throw new RowSkippedException('product_type tidak valid. Pilihan: '.implode(', ', array_column(ProductType::cases(), 'value')).'.');
        }
        if (filled($row['status'] ?? null)) {
            $data['status'] = ProductStatus::tryFrom(strtolower($row['status']))
                ?? throw new RowSkippedException('status tidak valid. Pilihan: '.implode(', ', array_column(ProductStatus::cases(), 'value')).'.');
        }
        foreach (['short_description', 'description'] as $field) {
            if (array_key_exists($field, $row)) {
                $data[$field] = $row[$field];
            }
        }
        if (isset($data['short_description']) && mb_strlen($data['short_description']) > 500) {
            throw new RowSkippedException('Kolom short_description maksimal 500 karakter.');
        }
        foreach (self::DECIMALS as $field) {
            if (array_key_exists($field, $row)) {
                $data[$field] = $this->decimal($row[$field], $field);
            }
        }
        if (filled($row['min_stock'] ?? null)) {
            $data['min_stock'] = $this->integer($row['min_stock'], 'min_stock');
        }

        $regular = $data['regular_price'] ?? $product?->regular_price;
        if ($regular === null) {
            throw new RowSkippedException('Kolom regular_price wajib diisi.');
        }
        $sale = array_key_exists('sale_price', $data) ? $data['sale_price'] : $product?->sale_price;
        if ($sale !== null && (float) $sale > (float) $regular) {
            throw new RowSkippedException('sale_price tidak boleh lebih besar dari regular_price.');
        }

        if ($product) {
            $product->update($data);

            return ImportResult::UPDATED;
        }

        Product::create([
            'product_type' => ProductType::PHYSICAL,
            'status' => ProductStatus::DRAFT,
            ...$data,
            'slug' => Product::uniqueSlug($data['name']),
        ]);

        return ImportResult::CREATED;
    }

    private function findProduct(array $row): ?Product
    {
        if (filled($row['id'] ?? null)) {
            return Product::query()->find(trim($row['id']))
                ?? throw new RowSkippedException("Produk dengan id {$row['id']} tidak ditemukan. Kosongkan kolom id untuk membuat produk baru.");
        }

        return filled($row['sku'] ?? null) ? Product::query()->where('sku', trim($row['sku']))->first() : null;
    }

    private function resolveCategory(?string $value): ?string
    {
        if (blank($value)) {
            return null;
        }

        return Category::query()
            ->where('slug', Str::slug($value))
            ->orWhereRaw('lower(name) = ?', [mb_strtolower(trim($value))])
            ->value('id') ?? throw new RowSkippedException("Kategori \"{$value}\" tidak ditemukan.");
    }

    private function decimal(?string $value, string $field): ?float
    {
        if (blank($value)) {
            return null;
        }
        $value = str_replace([' ', 'Rp', 'rp'], '', $value);
        if (! is_numeric($value) || (float) $value < 0) {
            throw new RowSkippedException("Kolom {$field} harus angka ≥ 0.");
        }

        return (float) $value;
    }

    private function integer(string $value, string $field): int
    {
        $value = trim($value);
        // XLSX numbers may arrive as "10.0".
        if (! is_numeric($value) || (float) $value < 0 || floor((float) $value) != (float) $value) {
            throw new RowSkippedException("Kolom {$field} harus angka bulat ≥ 0.");
        }

        return (int) $value;
    }
}
