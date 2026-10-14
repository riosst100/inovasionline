<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductStockController extends Controller
{
    /**
     * Products that already have stock set in at least one warehouse.
     */
    public function index(Request $request): JsonResponse
    {
        $search = trim($request->string('search')->toString());
        $warehouseId = $request->string('warehouse_id')->toString();

        $products = Product::query()
            ->whereHas('warehouses', fn ($q) => $q->when($warehouseId !== '', fn ($q) => $q->where('warehouses.id', $warehouseId)))
            ->with(['warehouses:id,code,name', 'images'])
            ->when($search !== '', fn ($q) => $q->where(
                fn ($q) => $q->where('name', 'ilike', "%{$search}%")->orWhere('sku', 'ilike', "%{$search}%")
            ))
            ->orderBy('name')
            ->paginate($request->integer('per_page', 20));

        $items = collect($products->items())->map(fn (Product $product) => $this->transform($product));

        return ApiResponse::success($items, 'Product stocks retrieved successfully.', [
            'current_page' => $products->currentPage(),
            'last_page' => $products->lastPage(),
            'per_page' => $products->perPage(),
            'total' => $products->total(),
        ]);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'stocks' => ['present', 'array'],
            'stocks.*.warehouse_id' => ['required', 'distinct', 'exists:warehouses,id'],
            'stocks.*.quantity' => ['required', 'integer', 'min:0'],
        ]);

        $stocks = collect($data['stocks']);

        DB::transaction(function () use ($product, $stocks) {
            $product->warehouses()->sync(
                $stocks->mapWithKeys(fn ($row) => [
                    $row['warehouse_id'] => ['quantity' => $row['quantity']],
                ])->all()
            );
            $product->update(['stock' => $stocks->sum('quantity')]);
        });

        $product->load(['warehouses:id,code,name', 'images']);

        return ApiResponse::success($this->transform($product), 'Product stock updated successfully.');
    }

    /**
     * @return array<string, mixed>
     */
    private function transform(Product $product): array
    {
        $path = $product->images->firstWhere('is_primary', true)?->path ?? $product->images->first()?->path;

        return [
            'id' => $product->id,
            'name' => $product->name,
            'sku' => $product->sku,
            'min_stock' => $product->min_stock,
            'image_url' => $path ? (str_starts_with($path, 'http') ? $path : asset('storage/'.$path)) : null,
            'total' => (int) $product->warehouses->sum(fn ($w) => $w->pivot->quantity),
            'stocks' => $product->warehouses->map(fn ($w) => [
                'warehouse_id' => $w->id,
                'warehouse_code' => $w->code,
                'warehouse_name' => $w->name,
                'quantity' => (int) $w->pivot->quantity,
            ])->values(),
        ];
    }
}
