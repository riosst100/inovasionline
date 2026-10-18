<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppInstall;
use App\Models\CartItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    private const ACTIVE_ORDER_STATUSES = [
        OrderStatus::PENDING,
        OrderStatus::PROCESSING,
        OrderStatus::READY,
        OrderStatus::ON_DELIVERY,
    ];

    private const TOP_LIMIT = 5;

    private const BEST_SELLER_DAYS = 30;

    public function index(): JsonResponse
    {
        $today = now()->startOfDay();
        $onlineSince = now()->subMinutes(AppInstall::ONLINE_MINUTES);

        $statusCounts = Order::query()
            ->toBase()
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $ordersToday = Order::query()
            ->where('created_at', '>=', $today)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->toBase()
            ->selectRaw('count(*) as total, coalesce(sum(grand_total), 0) as revenue')
            ->first();

        return ApiResponse::success([
            'orders' => [
                'active' => (int) collect(self::ACTIVE_ORDER_STATUSES)->sum(fn (OrderStatus $s) => $statusCounts[$s->value] ?? 0),
                'by_status' => collect(OrderStatus::cases())
                    ->mapWithKeys(fn (OrderStatus $s) => [$s->value => (int) ($statusCounts[$s->value] ?? 0)]),
                'today' => (int) $ordersToday->total,
                'revenue_today' => (float) $ordersToday->revenue,
            ],
            'users' => [
                'online' => AppInstall::query()->where('last_seen_at', '>=', $onlineSince)->count(),
                'active_today' => AppInstall::query()->where('last_seen_at', '>=', $today)->count(),
                'registered' => User::query()->where('role', UserRole::CUSTOMER)->count(),
                'registered_today' => User::query()->where('role', UserRole::CUSTOMER)->where('created_at', '>=', $today)->count(),
            ],
            'installs' => [
                'total' => AppInstall::query()->count(),
                'today' => AppInstall::query()->where('first_seen_at', '>=', $today)->count(),
            ],
            'funnel' => [
                // Installs whose latest heartbeat was from the checkout screen.
                'checking_out' => AppInstall::query()
                    ->where('last_seen_at', '>=', $onlineSince)
                    ->where('current_screen', 'like', '/checkout%')
                    ->count(),
                'carts_with_items' => CartItem::query()->distinct()->count('cart_id'),
                'added_to_cart_today' => CartItem::query()->where('created_at', '>=', $today)->count(),
                'awaiting_payment' => Order::query()
                    ->where('status', OrderStatus::PENDING)
                    ->where('payment_status', 'unpaid')
                    ->count(),
            ],
            'best_sellers' => $this->bestSellers(),
            'most_viewed' => $this->mostViewed(),
            'best_seller_days' => self::BEST_SELLER_DAYS,
            'online_minutes' => AppInstall::ONLINE_MINUTES,
        ], 'Dashboard retrieved successfully.');
    }

    private function bestSellers(): array
    {
        $rows = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.status', '!=', OrderStatus::CANCELLED->value)
            ->where('orders.created_at', '>=', now()->subDays(self::BEST_SELLER_DAYS))
            ->whereNotNull('order_items.product_id')
            ->groupBy('order_items.product_id')
            ->orderByDesc('sold')
            ->limit(self::TOP_LIMIT)
            ->toBase()
            ->select('order_items.product_id', DB::raw('sum(order_items.quantity) as sold'), DB::raw('sum(order_items.line_total) as revenue'))
            ->get();

        $products = Product::query()
            ->with('images')
            ->whereIn('id', $rows->pluck('product_id'))
            ->get()
            ->keyBy('id');

        return $rows
            ->filter(fn ($row) => $products->has($row->product_id))
            ->map(fn ($row) => [
                ...$this->productSummary($products[$row->product_id]),
                'sold' => (int) $row->sold,
                'revenue' => (float) $row->revenue,
            ])
            ->values()
            ->all();
    }

    private function mostViewed(): array
    {
        return Product::query()
            ->with('images')
            ->where('view_count', '>', 0)
            ->orderByDesc('view_count')
            ->limit(self::TOP_LIMIT)
            ->get()
            ->map(fn (Product $product) => [
                ...$this->productSummary($product),
                'views' => (int) $product->view_count,
            ])
            ->all();
    }

    private function productSummary(Product $product): array
    {
        $image = $product->images->firstWhere('is_primary', true) ?? $product->images->first();

        return [
            'id' => $product->id,
            'name' => $product->name,
            'image_url' => $image
                ? (str_starts_with($image->path, 'http') ? $image->path : asset('storage/'.$image->path))
                : null,
        ];
    }
}
