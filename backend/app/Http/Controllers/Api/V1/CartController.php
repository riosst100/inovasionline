<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Cart\AddCartItemRequest;
use App\Http\Requests\Cart\UpdateCartItemRequest;
use App\Http\Resources\CartItemResource;
use App\Models\CartItem;
use App\Models\Product;
use App\Services\CartService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class CartController extends Controller
{
    public function __construct(private readonly CartService $cartService) {}

    public function index(Request $request): JsonResponse
    {
        $cart = $this->cartService->cartForUser($request->user());
        $cart->load(['items.product.images', 'items.product.store', 'items.variant']);

        $groups = $cart->items
            ->groupBy(fn (CartItem $item) => $item->product->store_id)
            ->map(function ($items) {
                $store = $items->first()->product->store;
                $itemResources = CartItemResource::collection($items)->resolve();

                return [
                    'store' => [
                        'id' => $store->id,
                        'name' => $store->name,
                        'slug' => $store->slug,
                        'logo_url' => $store->logo_path ? asset('storage/'.$store->logo_path) : null,
                    ],
                    'items' => $itemResources,
                    'subtotal' => array_sum(array_column($itemResources, 'line_total')),
                ];
            })
            ->values();

        return ApiResponse::success([
            'stores' => $groups,
            'grand_total' => $groups->sum('subtotal'),
            'item_count' => $cart->items->sum('quantity'),
        ], 'Cart retrieved successfully.');
    }

    public function store(AddCartItemRequest $request): JsonResponse
    {
        $product = Product::findOrFail($request->validated('product_id'));

        try {
            $this->cartService->addItem(
                $request->user(),
                $product,
                $request->validated('product_variant_id'),
                $request->validated('quantity'),
            );
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return $this->index($request);
    }

    public function update(UpdateCartItemRequest $request, CartItem $cartItem): JsonResponse
    {
        try {
            $this->cartService->updateQuantity($request->user(), $cartItem, $request->validated('quantity'));
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 403);
        }

        return $this->index($request);
    }

    public function destroy(Request $request, CartItem $cartItem): JsonResponse
    {
        try {
            $this->cartService->removeItem($request->user(), $cartItem);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 403);
        }

        return $this->index($request);
    }
}
