<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PublicProductResource;
use App\Http\Resources\PublicStoreResource;
use App\Models\Product;
use App\Models\SearchLog;
use App\Models\SearchResultClick;
use App\Models\Store;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\StoreStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SearchController extends Controller
{
    /**
     * Match if the name contains any of the keyword's words, ranking full-phrase
     * matches above partial word matches.
     */
    private function applyNameSearch(Builder $query, string $column, string $keyword): Builder
    {
        $keyword = trim($keyword);
        $words = array_filter(explode(' ', $keyword));

        if ($words === []) {
            return $query->whereRaw('1 = 0');
        }

        $query->where(function (Builder $query) use ($column, $words) {
            foreach ($words as $word) {
                $query->orWhere($column, 'ilike', '%'.$word.'%');
            }
        });

        return $query->orderByRaw("case when {$column} ilike ? then 0 else 1 end", ['%'.$keyword.'%']);
    }

    public function suggestions(Request $request): JsonResponse
    {
        $request->validate([
            'q' => ['required', 'string', 'min:1', 'max:100'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:20'],
        ]);

        $keyword = mb_strtolower(trim($request->string('q')->toString()));
        $limit = $request->integer('limit', 8);

        $suggestions = SearchLog::query()
            ->where('keyword', 'like', "%{$keyword}%")
            ->orderByDesc('search_count')
            ->orderByDesc('last_searched_at')
            ->limit($limit)
            ->pluck('keyword');

        return ApiResponse::success($suggestions, 'Search suggestions retrieved successfully.');
    }

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'q' => ['required', 'string', 'min:1', 'max:100'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $keyword = $request->string('q')->toString();
        $limit = $request->integer('limit', 24);

        SearchLog::record($keyword);

        $products = $this->applyNameSearch(
            Product::query()->where('status', ProductStatus::ACTIVE),
            'name',
            $keyword
        )
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0), 'store'])
            ->withSum(['orderItems as order_items_sum_quantity' => function ($query) {
                $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
            }], 'quantity')
            ->orderByDesc('order_items_sum_quantity')
            ->limit($limit)
            ->get();

        $stores = $this->applyNameSearch(
            Store::query()->where('status', StoreStatus::OPEN)->whereNotNull('approved_at'),
            'name',
            $keyword
        )
            ->withCount('products')
            ->withCount(['orders as order_items_sum_quantity' => function ($query) {
                $query->where('status', OrderStatus::COMPLETED);
            }])
            ->orderByDesc('order_items_sum_quantity')
            ->limit($limit)
            ->get();

        return ApiResponse::success([
            'products' => PublicProductResource::collection($products),
            'stores' => PublicStoreResource::collection($stores),
        ], 'Search results retrieved successfully.');
    }

    public function popular(Request $request): JsonResponse
    {
        $request->validate([
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $limit = $request->integer('limit', 12);

        $products = Product::query()
            ->where('status', ProductStatus::ACTIVE)
            ->withCount('searchResultClicks')
            ->having('search_result_clicks_count', '>', 0)
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0), 'store'])
            ->orderByDesc('search_result_clicks_count')
            ->limit($limit)
            ->get();

        return ApiResponse::success(
            PublicProductResource::collection($products),
            'Popular search results retrieved successfully.'
        );
    }

    public function click(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => ['required', 'string', 'exists:products,id'],
            'keyword' => ['required', 'string', 'max:100'],
        ]);

        SearchResultClick::create([
            'product_id' => $validated['product_id'],
            'user_id' => $request->user()?->id,
            'keyword' => mb_strtolower(trim($validated['keyword'])),
        ]);

        return ApiResponse::success(null, 'Search result click recorded successfully.');
    }
}
