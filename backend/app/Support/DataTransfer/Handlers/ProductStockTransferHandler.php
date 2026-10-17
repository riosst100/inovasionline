<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Product;
use App\Models\Warehouse;
use App\Services\ProductStockService;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * One row per product × warehouse. Products are matched on `product_id`, then
 * `sku`; warehouses on `warehouse_code`. Importing sets that warehouse's
 * quantity; the product's total is the sum over warehouses. `product_name` and
 * `warehouse_name` are informational only.
 */
class ProductStockTransferHandler implements TransferHandler
{
    /** @var array<string, string> warehouse code => id */
    private ?array $warehouseIds = null;

    public function __construct(private readonly ProductStockService $stockService) {}

    public function label(): string
    {
        return 'Stok Produk';
    }

    public function headers(): array
    {
        return ['product_id', 'sku', 'product_name', 'warehouse_code', 'warehouse_name', 'quantity'];
    }

    public function sampleRow(): array
    {
        $product = Product::query()->whereNotNull('sku')->orderBy('name')->first(['sku', 'name']);
        $warehouse = Warehouse::query()->orderBy('code')->first(['code', 'name']);

        return [
            'sku' => $product->sku ?? 'SKU-PRODUK',
            'product_name' => $product->name ?? 'Nama produk (tidak dibaca saat import)',
            'warehouse_code' => $warehouse->code ?? 'KODE-GUDANG',
            'warehouse_name' => $warehouse->name ?? null,
            'quantity' => '10',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        $search = trim((string) ($filters['search'] ?? ''));
        $warehouseId = (string) ($filters['warehouse_id'] ?? '');

        return Product::query()
            ->join('product_warehouse_stocks as pws', 'pws.product_id', '=', 'products.id')
            ->join('warehouses as w', 'w.id', '=', 'pws.warehouse_id')
            ->select([
                'products.id as product_id', 'products.sku', 'products.name as product_name',
                'w.code as warehouse_code', 'w.name as warehouse_name', 'pws.quantity',
            ])
            ->when($warehouseId !== '', fn ($q) => $q->where('w.id', $warehouseId))
            ->when($search !== '', fn ($q) => $q->where(
                fn ($q) => $q->where('products.name', 'ilike', "%{$search}%")->orWhere('products.sku', 'ilike', "%{$search}%")
            ))
            ->orderBy('products.name')
            ->orderBy('products.id')
            ->orderBy('w.code');
    }

    public function exportRow(Model $model): array
    {
        return [
            'product_id' => $model->getAttribute('product_id'),
            'sku' => $model->getAttribute('sku'),
            'product_name' => $model->getAttribute('product_name'),
            'warehouse_code' => $model->getAttribute('warehouse_code'),
            'warehouse_name' => $model->getAttribute('warehouse_name'),
            'quantity' => (int) $model->getAttribute('quantity'),
        ];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $product = $this->findProduct($row);

        $code = strtoupper(trim((string) ($row['warehouse_code'] ?? '')));
        if ($code === '') {
            throw new RowSkippedException('Kolom warehouse_code wajib diisi.');
        }
        $this->warehouseIds ??= Warehouse::query()->pluck('id', 'code')->mapWithKeys(fn ($id, $c) => [strtoupper($c) => $id])->all();
        $warehouseId = $this->warehouseIds[$code] ?? throw new RowSkippedException("Gudang dengan kode \"{$code}\" tidak ditemukan.");

        $quantity = trim((string) ($row['quantity'] ?? ''));
        // XLSX numbers may arrive as "10.0".
        if ($quantity === '' || ! is_numeric($quantity) || (float) $quantity < 0 || floor((float) $quantity) != (float) $quantity) {
            throw new RowSkippedException('Kolom quantity wajib berupa angka bulat ≥ 0.');
        }

        $exists = $product->warehouses()->whereKey($warehouseId)->exists();
        $this->stockService->set($product, [$warehouseId => (int) $quantity]);

        return $exists ? ImportResult::UPDATED : ImportResult::CREATED;
    }

    private function findProduct(array $row): Product
    {
        if (filled($row['product_id'] ?? null)) {
            return Product::query()->find(trim($row['product_id']))
                ?? throw new RowSkippedException("Produk dengan id {$row['product_id']} tidak ditemukan.");
        }
        if (filled($row['sku'] ?? null)) {
            return Product::query()->where('sku', trim($row['sku']))->first()
                ?? throw new RowSkippedException("Produk dengan SKU \"{$row['sku']}\" tidak ditemukan.");
        }

        throw new RowSkippedException('Isi kolom product_id atau sku.');
    }
}
