<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\PublicProductResource;
use App\Models\Category;
use App\Models\Product;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\ProductStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $categories = Category::query()
            ->where('is_active', true)
            ->when($request->boolean('root_only'), fn ($query) => $query->whereNull('parent_id'))
            ->orderBy('sort_order')
            ->get();

        $this->attachProductCounts($categories);

        return ApiResponse::success(CategoryResource::collection($categories), 'Categories retrieved successfully.');
    }

    public function show(Request $request, string $slug): JsonResponse
    {
        $category = Category::query()
            ->where('slug', $slug)
            ->where('is_active', true)
            ->firstOrFail();

        $categoryIds = [$category->id, ...$category->children()->pluck('id')];

        $products = Product::query()
            ->whereIn('category_id', $categoryIds)
            ->where('status', ProductStatus::ACTIVE)
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0), 'store'])
            ->withSum(['orderItems as order_items_sum_quantity' => function ($query) {
                $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
            }], 'quantity')
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::success([
            'category' => new CategoryResource($category),
            'products' => PublicProductResource::collection($products->items()),
        ], 'Category retrieved successfully.', [
            'current_page' => $products->currentPage(),
            'last_page' => $products->lastPage(),
            'per_page' => $products->perPage(),
            'total' => $products->total(),
        ]);
    }

    /**
     * Sets `products_count` on each category: active products in the category
     * itself plus its direct children, matching what show() lists.
     */
    private function attachProductCounts($categories): void
    {
        $perCategory = Product::query()
            ->where('status', ProductStatus::ACTIVE)
            ->selectRaw('category_id, count(*) as total')
            ->groupBy('category_id')
            ->pluck('total', 'category_id');

        $parentById = Category::query()->whereNotNull('parent_id')->pluck('parent_id', 'id');

        $totals = [];
        foreach ($perCategory as $categoryId => $total) {
            $totals[$categoryId] = ($totals[$categoryId] ?? 0) + $total;
            $parentId = $parentById[$categoryId] ?? null;
            if ($parentId !== null) {
                $totals[$parentId] = ($totals[$parentId] ?? 0) + $total;
            }
        }

        foreach ($categories as $category) {
            $category->setAttribute('products_count', (int) ($totals[$category->id] ?? 0));
        }
    }
}
