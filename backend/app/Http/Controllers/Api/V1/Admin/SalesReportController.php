<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Enums\UserRole;
use App\Support\Reports\SoldItems;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Dashboard > Laporan penjualan: omzet and orders of a period (default today, WIB) set against
 * the period of equal length right before it. Cancelled orders never count towards omzet.
 */
class SalesReportController extends Controller
{
    private const TIMEZONE = WalletTopupController::TIMEZONE;

    private const MAX_DAYS = 366;

    private const TOP_LIMIT = 5;

    private const RECENT_LIMIT = 8;

    private const UNIT_COST = SoldItems::UNIT_COST;

    private const OPEN_STATUSES = [
        OrderStatus::PENDING,
        OrderStatus::PROCESSING,
        OrderStatus::READY,
        OrderStatus::ON_DELIVERY,
    ];

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
        ]);

        $today = now(self::TIMEZONE)->toDateString();
        $fromDate = $data['date_from'] ?? $data['date_to'] ?? $today;
        $toDate = $data['date_to'] ?? $fromDate;

        $from = WalletTopupController::startOfDay($fromDate);
        $to = WalletTopupController::startOfDay($toDate)->addDay();
        $days = (int) round($from->diffInDays($to));
        if ($days > self::MAX_DAYS) {
            return ApiResponse::error('Rentang tanggal maksimal '.self::MAX_DAYS.' hari.', [], 422);
        }

        $prevFrom = $from->copy()->subDays($days);
        $hourly = $days === 1;

        $monthStart = WalletTopupController::startOfDay(now(self::TIMEZONE)->startOfMonth()->toDateString());
        $allTime = $this->summary(Carbon::createFromTimestamp(0), now()->addSecond());
        $thisMonth = $this->summary($monthStart, now()->addSecond());

        return ApiResponse::success([
            'period' => [
                'date_from' => $fromDate,
                'date_to' => $toDate,
                'days' => $days,
                'summary' => $this->summary($from, $to),
            ],
            'previous' => [
                'date_from' => $prevFrom->copy()->tz(self::TIMEZONE)->toDateString(),
                'date_to' => $from->copy()->subDay()->tz(self::TIMEZONE)->toDateString(),
                'summary' => $this->summary($prevFrom, $from),
            ],
            'granularity' => $hourly ? 'hour' : 'day',
            'series' => $this->series($from, $to, $prevFrom, $hourly, $days),
            'by_status' => $this->byStatus($from, $to),
            'by_payment_method' => $this->byPaymentMethod($from, $to),
            'top_products' => $this->topProducts($from, $to),
            'recent_orders' => $this->recentOrders($from, $to),
            'overall' => [
                'revenue_total' => $allTime['revenue'],
                'orders_total' => $allTime['orders'],
                'profit_total' => $allTime['gross_profit'],
                'revenue_this_month' => $thisMonth['revenue'],
                'orders_this_month' => $thisMonth['orders'],
                'profit_this_month' => $thisMonth['gross_profit'],
                'open_orders' => Order::query()->whereIn('status', self::OPEN_STATUSES)->count(),
                'awaiting_payment' => Order::query()
                    ->where('status', OrderStatus::PENDING)
                    ->where('payment_status', PaymentStatus::UNPAID)
                    ->count(),
            ],
        ], 'Sales report retrieved successfully.');
    }

    /** Items of the period's non-cancelled orders, joined to their product for its cost. */
    private function soldItems(Carbon $from, Carbon $to)
    {
        return SoldItems::query($from, $to);
    }

    /** Orders that count as a sale: everything but cancelled. */
    private function sold()
    {
        return Order::query()->where('status', '!=', OrderStatus::CANCELLED);
    }

    private function summary(Carbon $from, Carbon $to): array
    {
        $orders = Order::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->toBase()
            ->selectRaw('
                count(*) filter (where status <> ?) as orders,
                coalesce(sum(grand_total) filter (where status <> ?), 0) as revenue,
                coalesce(sum(grand_total) filter (where status <> ? and payment_status = ?), 0) as revenue_paid,
                coalesce(sum(discount_total) filter (where status <> ?), 0) as discount,
                coalesce(sum(shipping_fee) filter (where status <> ?), 0) as shipping,
                count(*) filter (where status = ?) as completed,
                count(*) filter (where status = ?) as cancelled,
                count(distinct user_id) filter (where status <> ?) as buyers
            ', [
                OrderStatus::CANCELLED->value,
                OrderStatus::CANCELLED->value,
                OrderStatus::CANCELLED->value, PaymentStatus::PAID->value,
                OrderStatus::CANCELLED->value,
                OrderStatus::CANCELLED->value,
                OrderStatus::COMPLETED->value,
                OrderStatus::CANCELLED->value,
                OrderStatus::CANCELLED->value,
            ])
            ->first();

        $items = $this->soldItems($from, $to)
            ->toBase()
            ->selectRaw('
                coalesce(sum(order_items.quantity), 0) as quantity,
                coalesce(sum(order_items.line_total), 0) as sales,
                coalesce(sum('.self::UNIT_COST.' * order_items.quantity), 0) as cost,
                coalesce(sum(order_items.quantity) filter (where '.self::UNIT_COST.' is null), 0) as without_cost
            ')
            ->first();

        $count = (int) $orders->orders;
        $revenue = (float) $orders->revenue;
        $cost = (float) $items->cost;
        // Goods sold minus order discounts and cost; shipping and service fees are left out.
        $profit = (float) $items->sales - (float) $orders->discount - $cost;
        $netSales = (float) $items->sales - (float) $orders->discount;

        return [
            'revenue' => $revenue,
            'revenue_paid' => (float) $orders->revenue_paid,
            'orders' => $count,
            'average_order' => $count > 0 ? round($revenue / $count, 2) : 0.0,
            'items_sold' => (int) $items->quantity,
            'product_sales' => $netSales,
            'cost' => $cost,
            'gross_profit' => $profit,
            'margin' => $netSales > 0 ? round($profit / $netSales * 100, 1) : 0.0,
            'items_without_cost' => (int) $items->without_cost,
            'buyers' => (int) $orders->buyers,
            'discount' => (float) $orders->discount,
            'shipping' => (float) $orders->shipping,
            'completed' => (int) $orders->completed,
            'cancelled' => (int) $orders->cancelled,
            'new_customers' => User::query()
                ->where('role', UserRole::CUSTOMER)
                ->where('created_at', '>=', $from)
                ->where('created_at', '<', $to)
                ->count(),
        ];
    }

    /**
     * Omzet and orders per hour (single day) or per day, for the period and the one before it,
     * aligned by bucket index so the two lines can be drawn on top of each other.
     */
    private function series(Carbon $from, Carbon $to, Carbon $prevFrom, bool $hourly, int $days): array
    {
        $buckets = $hourly ? 24 : $days;
        $current = $this->bucketed($from, $to, $hourly);
        $previous = $this->bucketed($prevFrom, $from, $hourly);

        $rows = [];
        for ($i = 0; $i < $buckets; $i++) {
            $rows[] = [
                'label' => $hourly
                    ? sprintf('%02d:00', $i)
                    : $from->copy()->tz(self::TIMEZONE)->addDays($i)->toDateString(),
                'revenue' => (float) ($current[$i]->revenue ?? 0),
                'orders' => (int) ($current[$i]->orders ?? 0),
                'previous_revenue' => (float) ($previous[$i]->revenue ?? 0),
                'previous_orders' => (int) ($previous[$i]->orders ?? 0),
            ];
        }

        return $rows;
    }

    private function bucketed(Carbon $from, Carbon $to, bool $hourly)
    {
        $local = "(created_at at time zone 'UTC' at time zone '".self::TIMEZONE."')";
        $start = $from->copy()->tz(self::TIMEZONE)->toDateString();
        $bucket = $hourly
            ? "extract(hour from $local)::int"
            : "($local::date - date '$start')";

        return $this->sold()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->toBase()
            ->selectRaw("$bucket as bucket, count(*) as orders, coalesce(sum(grand_total), 0) as revenue")
            ->groupByRaw($bucket)
            ->get()
            ->keyBy('bucket');
    }

    private function byStatus(Carbon $from, Carbon $to): array
    {
        $counts = Order::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->toBase()
            ->selectRaw('status, count(*) as total, coalesce(sum(grand_total), 0) as revenue')
            ->groupBy('status')
            ->get()
            ->keyBy('status');

        return collect(OrderStatus::cases())
            ->map(fn (OrderStatus $s) => [
                'status' => $s->value,
                'orders' => (int) ($counts[$s->value]->total ?? 0),
                'revenue' => (float) ($counts[$s->value]->revenue ?? 0),
            ])
            ->all();
    }

    private function byPaymentMethod(Carbon $from, Carbon $to): array
    {
        return $this->sold()
            ->leftJoin('payment_methods', 'payment_methods.id', '=', 'orders.payment_method_id')
            ->where('orders.created_at', '>=', $from)
            ->where('orders.created_at', '<', $to)
            ->toBase()
            ->selectRaw("coalesce(payment_methods.name, 'Lainnya') as method, count(*) as orders, coalesce(sum(orders.grand_total), 0) as revenue")
            ->groupByRaw("coalesce(payment_methods.name, 'Lainnya')")
            ->orderByDesc('revenue')
            ->get()
            ->map(fn ($r) => ['method' => $r->method, 'orders' => (int) $r->orders, 'revenue' => (float) $r->revenue])
            ->all();
    }

    private function topProducts(Carbon $from, Carbon $to): array
    {
        return $this->soldItems($from, $to)
            ->groupBy('order_items.product_id', 'order_items.product_name')
            ->orderByDesc('sold')
            ->limit(self::TOP_LIMIT)
            ->toBase()
            ->select(
                'order_items.product_id',
                'order_items.product_name',
                DB::raw('sum(order_items.quantity) as sold'),
                DB::raw('sum(order_items.line_total) as revenue'),
                DB::raw('sum('.self::UNIT_COST.' * order_items.quantity) as cost'),
                DB::raw('bool_or('.self::UNIT_COST.' is null) as missing_cost'),
            )
            ->get()
            ->map(fn ($r) => [
                'product_id' => $r->product_id,
                'name' => $r->product_name,
                'sold' => (int) $r->sold,
                'revenue' => (float) $r->revenue,
                // Null while any unit sold lacks a cost, so a partial figure is never shown as profit.
                'profit' => $r->missing_cost ? null : (float) $r->revenue - (float) $r->cost,
            ])
            ->all();
    }

    private function recentOrders(Carbon $from, Carbon $to): array
    {
        return Order::query()
            ->with('user:id,name')
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->latest()
            ->limit(self::RECENT_LIMIT)
            ->get()
            ->map(fn (Order $o) => [
                'id' => $o->id,
                'order_number' => $o->order_number,
                'customer' => $o->user?->name,
                'grand_total' => (float) $o->grand_total,
                'status' => $o->status->value,
                'payment_status' => $o->payment_status?->value,
                'created_at' => $o->created_at,
            ])
            ->all();
    }
}
