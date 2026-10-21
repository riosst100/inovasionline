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
        $cart->load(['items.product' => fn ($q) => $q->withStock(), 'items.product.images', 'items.variant']);

        // Products can be soft-deleted after being carted; drop those stale lines.
        [$valid, $stale] = $cart->items->partition(fn (CartItem $item) => $item->product !== null);
        if ($stale->isNotEmpty()) {
            CartItem::whereIn('id', $stale->pluck('id'))->delete();
        }

        $items = CartItemResource::collection($valid->values())->resolve();

        return ApiResponse::success([
            'items' => $items,
            'grand_total' => array_sum(array_column($items, 'line_total')),
            'item_count' => $valid->sum('quantity'),
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
