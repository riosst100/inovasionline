<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductImage;
use App\Services\ProductStockService;
use App\Support\Enums\ProductStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ProductController extends Controller
{
    public function __construct(private readonly ProductStockService $stockService) {}

    public function index(Request $request): JsonResponse
    {
        $search = trim($request->string('search')->toString());

        $products = Product::query()
            ->withStock()
            ->with(['category:id,name', 'images'])
            ->when($search !== '', fn ($query) => $query->where('name', 'ilike', "%{$search}%"))
            ->when(
                ProductStatus::tryFrom($request->string('status')->toString()),
                fn ($query, $status) => $query->where('status', $status)
            )
            ->latest()
            ->paginate($request->integer('per_page', 20));

        $items = collect($products->items())->map(fn (Product $product) => $this->transform($product));

        return ApiResponse::success($items, 'Products retrieved successfully.', [
            'current_page' => $products->currentPage(),
            'last_page' => $products->lastPage(),
            'per_page' => $products->perPage(),
            'total' => $products->total(),
        ]);
    }

    public function show(Product $product): JsonResponse
    {
        return $this->freshResponse($product, 'Product retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'short_description' => ['nullable', 'string', 'max:500'],
            'description' => ['nullable', 'string'],
            'regular_price' => ['required', 'numeric', 'min:0'],
            'sale_price' => ['nullable', 'numeric', 'min:0', 'lte:regular_price'],
            'stocks' => ['nullable', 'array'],
            'stocks.*.warehouse_id' => ['required', 'distinct', 'exists:warehouses,id'],
            'stocks.*.quantity' => ['required', 'integer', 'min:0'],
            'sku' => ['nullable', 'string', 'max:100', Rule::unique('products', 'sku')],
            'status' => ['required', Rule::enum(ProductStatus::class)],
        ], [
            'sku.unique' => 'SKU sudah digunakan.',
        ]);

        $stocks = $data['stocks'] ?? null;
        unset($data['stocks']);

        $product = DB::transaction(function () use ($data, $stocks) {
            $product = Product::create([...$data, 'slug' => Product::uniqueSlug($data['name'])]);

            if ($stocks !== null) {
                $this->stockService->set($product, $this->stockMap($stocks), detach: true);
            }

            return $product;
        });

        return $this->freshResponse($product, 'Product created successfully.');
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'short_description' => ['nullable', 'string', 'max:500'],
            'description' => ['nullable', 'string'],
            'regular_price' => ['required', 'numeric', 'min:0'],
            'sale_price' => ['nullable', 'numeric', 'min:0', 'lte:regular_price'],
            'stocks' => ['nullable', 'array'],
            'stocks.*.warehouse_id' => ['required', 'distinct', 'exists:warehouses,id'],
            'stocks.*.quantity' => ['required', 'integer', 'min:0'],
            'sku' => ['nullable', 'string', 'max:100', Rule::unique('products', 'sku')->ignore($product->id)],
            'status' => ['required', Rule::enum(ProductStatus::class)],
        ]);

        $stocks = $data['stocks'] ?? null;
        unset($data['stocks']);

        DB::transaction(function () use ($product, $data, $stocks) {
            if ($stocks !== null) {
                $this->stockService->set($product, $this->stockMap($stocks), detach: true);
            }

            $product->update($data);
        });

        return $this->freshResponse($product, 'Product updated successfully.');
    }

    public function bulkUpdateStatus(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['required', 'string'],
            'status' => ['required', Rule::enum(ProductStatus::class)],
        ]);

        $count = Product::whereIn('id', $data['ids'])->update(['status' => $data['status']]);

        return ApiResponse::success(['count' => $count], 'Products updated successfully.');
    }

    public function bulkDestroy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['required', 'string'],
        ]);

        $count = 0;
        Product::whereIn('id', $data['ids'])->get()->each(function (Product $product) use (&$count) {
            $product->delete();
            $count++;
        });

        return ApiResponse::success(['count' => $count], 'Products deleted successfully.');
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return ApiResponse::success(null, 'Product deleted successfully.');
    }

    public function storeImages(Request $request, Product $product): JsonResponse
    {
        $request->validate([
            'images' => ['required', 'array', 'min:1', 'max:10'],
            'images.*' => ['image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ]);

        $next = (int) $product->images()->max('sort_order') + 1;
        $hasPrimary = $product->images()->where('is_primary', true)->exists();

        foreach ($request->file('images') as $file) {
            $product->images()->create([
                'path' => $file->store('products', 'public'),
                'alt_text' => $product->name,
                'is_primary' => ! $hasPrimary,
                'sort_order' => $next++,
            ]);
            $hasPrimary = true;
        }

        return $this->freshResponse($product, 'Images uploaded successfully.');
    }

    public function setPrimaryImage(Product $product, ProductImage $image): JsonResponse
    {
        abort_unless($image->product_id === $product->id, 404);

        $product->images()->update(['is_primary' => false]);
        $order = 1;
        foreach ($product->images()->where('id', '!=', $image->id)->get() as $other) {
            $other->update(['sort_order' => $order++]);
        }
        $image->update(['is_primary' => true, 'sort_order' => 0]);

        return $this->freshResponse($product, 'Primary image updated successfully.');
    }

    public function destroyImage(Product $product, ProductImage $image): JsonResponse
    {
        abort_unless($image->product_id === $product->id, 404);

        $wasPrimary = $image->is_primary;
        if (! str_starts_with($image->path, 'http')) {
            Storage::disk('public')->delete($image->path);
        }
        $image->delete();

        if ($wasPrimary) {
            $product->images()->first()?->update(['is_primary' => true]);
        }

        return $this->freshResponse($product, 'Image deleted successfully.');
    }

    private function freshResponse(Product $product, string $message): JsonResponse
    {
        $product->load(['category:id,name', 'images', 'warehouses:id,name']);

        return ApiResponse::success($this->transform($product), $message);
    }

    public function updateStatus(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::enum(ProductStatus::class)],
        ]);

        $product->update(['status' => $data['status']]);
        $product->load(['category:id,name', 'images']);

        return ApiResponse::success($this->transform($product), 'Product status updated successfully.');
    }

    /**
     * @return array<string, mixed>
     */
    /**
     * @param  array<int, array{warehouse_id: string, quantity: int}>  $stocks
     * @return array<string, int>
     */
    private function stockMap(array $stocks): array
    {
        return collect($stocks)->mapWithKeys(fn ($row) => [$row['warehouse_id'] => (int) $row['quantity']])->all();
    }

    private function transform(Product $product): array
    {
        $path = $product->images->first()?->path;

        return [
            'id' => $product->id,
            'name' => $product->name,
            'slug' => $product->slug,
            'regular_price' => $product->regular_price,
            'sale_price' => $product->sale_price,
            'category_id' => $product->category_id,
            'sku' => $product->sku,
            'short_description' => $product->short_description,
            'description' => $product->description,
            'stock' => $product->stock,
            'status' => $product->status instanceof \BackedEnum ? $product->status->value : $product->status,
            'category_name' => $product->category?->name,
            'stocks' => $product->relationLoaded('warehouses')
                ? $product->warehouses->map(fn ($w) => [
                    'warehouse_id' => $w->id,
                    'quantity' => (int) $w->pivot->quantity,
                ])->values()
                : [],
            'images' => $product->images->map(fn ($img) => [
                'id' => $img->id,
                'url' => str_starts_with($img->path, 'http') ? $img->path : asset('storage/'.$img->path),
                'is_primary' => (bool) $img->is_primary,
            ])->values(),
            'image_url' => $path ? (str_starts_with($path, 'http') ? $path : asset('storage/'.$path)) : null,
        ];
    }
}
