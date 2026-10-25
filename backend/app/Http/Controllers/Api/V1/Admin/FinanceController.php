<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\SupplierBill;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Reports\SoldItems;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Keuangan > Laporan Keuangan and Keuntungan. Sales count by order date (WIB) and exclude
 * cancelled orders, like Dashboard > Laporan penjualan; gross profit uses the same SoldItems
 * query so both pages always agree.
 */
class FinanceController extends Controller
{
    private const TIMEZONE = WalletTopupController::TIMEZONE;

    private const MAX_DAYS = 366;

    private const PROFIT_ROW_LIMIT = 200;

    private const GROUPS = ['product', 'category', 'supplier', 'brand'];

    public function report(Request $request): JsonResponse
    {
        [$from, $to, $period] = $this->period($request);
        if ($from === null) {
            return ApiResponse::error('Rentang tanggal maksimal '.self::MAX_DAYS.' hari.', [], 422);
        }

        $orders = Order::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->toBase()
            ->selectRaw('
                count(*) as orders,
                coalesce(sum(grand_total), 0) as total,
                coalesce(sum(shipping_fee), 0) as shipping,
                coalesce(sum(service_fee), 0) as service_fee,
                coalesce(sum(tax_total), 0) as tax,
                coalesce(sum(grand_total) filter (where payment_status = ?), 0) as paid,
                coalesce(sum(grand_total) filter (where payment_status = ?), 0) as unpaid,
                coalesce(sum(grand_total) filter (where payment_status = ?), 0) as refunded
            ', [PaymentStatus::PAID->value, PaymentStatus::UNPAID->value, PaymentStatus::REFUNDED->value])
            ->first();

        $profit = self::profitTotals($from, $to);
        $shipping = (float) $orders->shipping;
        $serviceFee = (float) $orders->service_fee;
        $grossIncome = $profit['gross_profit'] + $shipping + $serviceFee;
        // Operating costs and other income the admin records in Keuangan > Cashflow.
        $manual = CompanyTransactionController::manualTotals($period['date_from'], $period['date_to']);

        $wallet = WalletTransaction::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->toBase()
            ->selectRaw('type, coalesce(sum(amount) filter (where amount > 0), 0) as credit, coalesce(sum(-amount) filter (where amount < 0), 0) as debit')
            ->groupBy('type')
            ->get();

        $today = SupplierBill::today();
        $bills = SupplierBill::query()->toBase()->selectRaw('
            coalesce(sum(amount) filter (where bill_date >= ? and bill_date < ?), 0) as billed,
            coalesce(sum(amount) filter (where paid_at >= ? and paid_at < ?), 0) as paid,
            coalesce(sum(amount) filter (where paid_at is null), 0) as outstanding,
            coalesce(sum(amount) filter (where paid_at is null and due_date < ?), 0) as overdue
        ', [$period['date_from'], $to->copy()->tz(self::TIMEZONE)->toDateString(), $from, $to, $today])->first();

        return ApiResponse::success([
            'period' => $period,
            'income_statement' => [
                ...$profit,
                'shipping' => $shipping,
                'service_fee' => $serviceFee,
                // Platform income before operating costs.
                'gross_income' => $grossIncome,
                'other_income' => $manual['income'],
                'operating_expenses' => $manual['expense'],
                'net_income' => $grossIncome + $manual['income'] - $manual['expense'],
            ],
            'sales' => [
                'orders' => (int) $orders->orders,
                'total' => (float) $orders->total,
                'tax' => (float) $orders->tax,
                'paid' => (float) $orders->paid,
                'unpaid' => (float) $orders->unpaid,
                'refunded' => (float) $orders->refunded,
            ],
            'by_payment_method' => $this->byPaymentMethod($from, $to),
            'wallet' => [
                'topup' => (float) ($wallet->firstWhere('type', WalletTransaction::TYPE_TOPUP)?->credit ?? 0),
                'spent' => (float) $wallet->sum('debit'),
                'other_credit' => (float) $wallet->where('type', '!=', WalletTransaction::TYPE_TOPUP)->sum('credit'),
                // Money held for customers right now: a liability, not income.
                'total_balance' => (float) User::query()->sum('wallet_balance'),
            ],
            'supplier_bills' => [
                'billed' => (float) $bills->billed,
                'paid' => (float) $bills->paid,
                'outstanding' => (float) $bills->outstanding,
                'overdue' => (float) $bills->overdue,
            ],
        ], 'Finance report retrieved successfully.');
    }

    public function profit(Request $request): JsonResponse
    {
        [$from, $to, $period] = $this->period($request);
        if ($from === null) {
            return ApiResponse::error('Rentang tanggal maksimal '.self::MAX_DAYS.' hari.', [], 422);
        }

        $group = $request->validate(['group' => ['nullable', Rule::in(self::GROUPS)]])['group'] ?? 'product';

        [$key, $name, $join] = match ($group) {
            'category' => ['products.category_id', "coalesce(categories.name, 'Tanpa kategori')", ['categories', 'categories.id', 'products.category_id']],
            'supplier' => ['products.supplier_id', "coalesce(suppliers.name, 'Tanpa supplier')", ['suppliers', 'suppliers.id', 'products.supplier_id']],
            'brand' => ['products.brand_id', "coalesce(brands.name, 'Tanpa brand')", ['brands', 'brands.id', 'products.brand_id']],
            default => ['order_items.product_id', 'max(order_items.product_name)', null],
        };

        $cost = SoldItems::UNIT_COST;
        $query = SoldItems::query($from, $to);
        if ($join) {
            $query->leftJoin(...$join);
        }

        $rows = $query
            ->toBase()
            ->selectRaw("
                {$key} as id,
                {$name} as name,
                sum(order_items.quantity) as quantity,
                sum(order_items.line_total) as revenue,
                sum({$cost} * order_items.quantity) as cost,
                bool_or({$cost} is null) as missing_cost
            ")
            ->groupByRaw($join ? "{$key}, {$name}" : $key)
            ->orderByDesc('revenue')
            ->limit(self::PROFIT_ROW_LIMIT)
            ->get()
            ->map(function ($r) {
                $revenue = (float) $r->revenue;
                // Null while any unit sold lacks a cost, so a partial figure is never shown as profit.
                $profit = $r->missing_cost ? null : $revenue - (float) $r->cost;

                return [
                    'id' => $r->id,
                    'name' => $r->name,
                    'quantity' => (int) $r->quantity,
                    'revenue' => $revenue,
                    'cost' => $r->missing_cost ? null : (float) $r->cost,
                    'profit' => $profit,
                    'margin' => $profit !== null && $revenue > 0 ? round($profit / $revenue * 100, 1) : null,
                ];
            });

        return ApiResponse::success([
            'period' => $period,
            'group' => $group,
            'totals' => self::profitTotals($from, $to),
            'rows' => $rows,
            'row_limit' => self::PROFIT_ROW_LIMIT,
        ], 'Profit report retrieved successfully.');
    }

    /**
     * Laba bersih as in report()'s income statement: gross profit + shipping + service fees
     * + other income − operating costs. Used by the dashboard overview.
     */
    public static function netIncome(Carbon $from, Carbon $to, string $fromDate, string $toDate): float
    {
        $fees = (float) Order::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->sum(DB::raw('coalesce(shipping_fee, 0) + coalesce(service_fee, 0)'));
        $manual = CompanyTransactionController::manualTotals($fromDate, $toDate);

        return self::profitTotals($from, $to)['gross_profit'] + $fees + $manual['income'] - $manual['expense'];
    }

    /** Same formula as Dashboard > Laporan penjualan: goods sold − order discounts − HPP. */
    public static function profitTotals(Carbon $from, Carbon $to): array
    {
        $items = SoldItems::query($from, $to)
            ->toBase()
            ->selectRaw('
                coalesce(sum(order_items.quantity), 0) as quantity,
                coalesce(sum(order_items.line_total), 0) as sales,
                coalesce(sum('.SoldItems::UNIT_COST.' * order_items.quantity), 0) as cost,
                coalesce(sum(order_items.quantity) filter (where '.SoldItems::UNIT_COST.' is null), 0) as without_cost
            ')
            ->first();

        $discount = (float) Order::query()
            ->where('created_at', '>=', $from)
            ->where('created_at', '<', $to)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->sum('discount_total');

        $sales = (float) $items->sales;
        $netSales = $sales - $discount;
        $cost = (float) $items->cost;
        $profit = $netSales - $cost;

        return [
            'product_sales' => $sales,
            'discount' => $discount,
            'net_sales' => $netSales,
            'cost' => $cost,
            'gross_profit' => $profit,
            'margin' => $netSales > 0 ? round($profit / $netSales * 100, 1) : 0.0,
            'items_sold' => (int) $items->quantity,
            'items_without_cost' => (int) $items->without_cost,
        ];
    }

    private function byPaymentMethod(Carbon $from, Carbon $to): array
    {
        $method = "coalesce(payment_methods.name, 'Lainnya')";

        return Order::query()
            ->leftJoin('payment_methods', 'payment_methods.id', '=', 'orders.payment_method_id')
            ->where('orders.status', '!=', OrderStatus::CANCELLED)
            ->where('orders.created_at', '>=', $from)
            ->where('orders.created_at', '<', $to)
            ->toBase()
            ->selectRaw("{$method} as method, count(*) as orders, coalesce(sum(orders.grand_total), 0) as total, coalesce(sum(orders.grand_total) filter (where orders.payment_status = ?), 0) as paid", [PaymentStatus::PAID->value])
            ->groupByRaw($method)
            ->orderByDesc('total')
            ->get()
            ->map(fn ($r) => ['method' => $r->method, 'orders' => (int) $r->orders, 'total' => (float) $r->total, 'paid' => (float) $r->paid])
            ->all();
    }

    /**
     * Defaults to this month (WIB). Returns [null, null, null] when the range is too long.
     *
     * @return array{0: ?Carbon, 1: ?Carbon, 2: ?array{date_from: string, date_to: string, days: int}}
     */
    private function period(Request $request): array
    {
        $data = $request->validate([
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
        ]);

        $now = now(self::TIMEZONE);
        $fromDate = $data['date_from'] ?? $now->copy()->startOfMonth()->toDateString();
        $toDate = $data['date_to'] ?? $now->toDateString();

        $from = WalletTopupController::startOfDay($fromDate);
        $to = WalletTopupController::startOfDay($toDate)->addDay();
        $days = (int) round($from->diffInDays($to));

        if ($days > self::MAX_DAYS) {
            return [null, null, null];
        }

        return [$from, $to, ['date_from' => $fromDate, 'date_to' => $toDate, 'days' => $days]];
    }
}
