<?php

namespace App\Services;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class CartService
{
    public function cartForUser(User $user): Cart
    {
        return Cart::firstOrCreate(['user_id' => $user->id]);
    }

    public function addItem(User $user, Product $product, ?string $variantId, int $quantity): CartItem
    {
        if ($variantId !== null && ! $product->variants()->where('id', $variantId)->exists()) {
            throw new RuntimeException('The selected variant does not belong to this product.');
        }

        return DB::transaction(function () use ($user, $product, $variantId, $quantity) {
            $cart = $this->cartForUser($user);

            $item = CartItem::query()
                ->where('cart_id', $cart->id)
                ->where('product_id', $product->id)
                ->where('product_variant_id', $variantId)
                ->first();

            if ($item) {
                $item->update(['quantity' => $item->quantity + $quantity]);

                return $item->fresh();
            }

            return CartItem::create([
                'cart_id' => $cart->id,
                'product_id' => $product->id,
                'product_variant_id' => $variantId,
                'quantity' => $quantity,
            ]);
        });
    }

    public function updateQuantity(User $user, CartItem $item, int $quantity): CartItem
    {
        $this->authorizeItem($user, $item);

        $item->update(['quantity' => $quantity]);

        return $item->fresh();
    }

    public function removeItem(User $user, CartItem $item): void
    {
        $this->authorizeItem($user, $item);

        $item->delete();
    }

    private function authorizeItem(User $user, CartItem $item): void
    {
        if ($item->cart->user_id !== $user->id) {
            throw new RuntimeException('This cart item does not belong to you.');
        }
    }
}
