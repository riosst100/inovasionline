<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Warehouse;
use App\Support\AppCache;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/**
 * The only place that writes product stock. Stock is stored per warehouse in
 * product_warehouse_stocks; a product's stock is the sum over its warehouses.
 */
class ProductStockService
{
    /**
     * Set quantities per warehouse. With $detach, warehouses missing from
     * $quantities are removed from the product.
     *
     * @param  array<string, int>  $quantities  warehouse id => quantity
     */
    public function set(Product $product, array $quantities, bool $detach = false): void
    {
        $rows = collect($quantities)->map(fn ($qty) => ['quantity' => max(0, (int) $qty)])->all();

        $detach
            ? $product->warehouses()->sync($rows)
            : $product->warehouses()->syncWithoutDetaching($rows);

        AppCache::bump('products');
    }

    /**
     * Set a single total for callers that do not know about warehouses (seller
     * API, legacy import): it goes to the product's only warehouse, or to the
     * default warehouse when the product has none yet.
     */
    public function setTotal(Product $product, int $quantity): void
    {
        $warehouseIds = $product->warehouses()->pluck('warehouses.id');

        if ($warehouseIds->count() > 1) {
            throw ValidationException::withMessages(['stock' => 'Produk memakai stok di beberapa gudang; atur stok per gudang.']);
        }

        $warehouseId = $warehouseIds->first() ?? $this->defaultWarehouseId()
            ?? throw ValidationException::withMessages(['stock' => 'Belum ada gudang. Buat gudang terlebih dahulu untuk mengatur stok.']);

        $this->set($product, [$warehouseId => $quantity]);
    }

    /**
     * Take stock for an order, preferring warehouses that cover the delivery
     * address, then the ones holding the most stock. Must run in a transaction.
     *
     * @return list<array{warehouse_id: string, quantity: int}>
     *
     * @throws RuntimeException when there is not enough stock
     */
    public function allocate(Product $product, int $quantity, ?string $districtCode = null, ?string $villageCode = null): array
    {
        $rows = DB::table('product_warehouse_stocks as pws')
            ->where('pws.product_id', $product->id)
            ->where('pws.quantity', '>', 0)
            ->select('pws.warehouse_id', 'pws.quantity')
            ->selectRaw('exists (
                select 1 from warehouse_coverage_areas c
                where c.warehouse_id = pws.warehouse_id
                  and trim(c.district_code) = ?
                  and (c.village_code is null or trim(c.village_code) = ?)
            ) as covers', [(string) $districtCode, (string) $villageCode])
            ->lockForUpdate()
            ->get()
            ->sortBy([['covers', 'desc'], ['quantity', 'desc']]);

        if ($rows->sum('quantity') < $quantity) {
            throw new RuntimeException("Insufficient stock for {$product->name}.");
        }

        $allocations = [];
        $remaining = $quantity;
        foreach ($rows as $row) {
            if ($remaining === 0) {
                break;
            }
            $take = min($remaining, (int) $row->quantity);
            DB::table('product_warehouse_stocks')
                ->where('product_id', $product->id)
                ->where('warehouse_id', $row->warehouse_id)
                ->update(['quantity' => DB::raw('quantity - '.$take), 'updated_at' => now()]);
            $allocations[] = ['warehouse_id' => $row->warehouse_id, 'quantity' => $take];
            $remaining -= $take;
        }

        // Another checkout just took stock: phones must not keep showing the old number.
        AppCache::bump('products');

        return $allocations;
    }

    /**
     * Return stock taken by allocate(). Orders placed before warehouse
     * allocations were recorded have none; their quantity goes back to the
     * product's first warehouse (or the default one).
     *
     * @param  list<array{warehouse_id: string, quantity: int}>|null  $allocations
     */
    public function release(string $productId, ?array $allocations, int $fallbackQuantity): void
    {
        if (empty($allocations)) {
            $warehouseId = DB::table('product_warehouse_stocks')->where('product_id', $productId)->orderBy('warehouse_id')->value('warehouse_id')
                ?? $this->defaultWarehouseId();
            if (! $warehouseId) {
                return;
            }
            $allocations = [['warehouse_id' => $warehouseId, 'quantity' => $fallbackQuantity]];
        }

        $now = now();
        foreach ($allocations as $a) {
            $updated = DB::table('product_warehouse_stocks')
                ->where('product_id', $productId)
                ->where('warehouse_id', $a['warehouse_id'])
                ->update(['quantity' => DB::raw('quantity + '.(int) $a['quantity']), 'updated_at' => $now]);

            if ($updated === 0 && Warehouse::query()->whereKey($a['warehouse_id'])->exists()) {
                DB::table('product_warehouse_stocks')->insert([
                    'product_id' => $productId,
                    'warehouse_id' => $a['warehouse_id'],
                    'quantity' => (int) $a['quantity'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        AppCache::bump('products');
    }

    public function defaultWarehouseId(): ?string
    {
        return Warehouse::query()->orderByDesc('is_active')->orderBy('code')->value('id');
    }
}
