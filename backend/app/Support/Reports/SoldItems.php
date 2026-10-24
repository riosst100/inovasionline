<?php

namespace App\Support\Reports;

use App\Models\OrderItem;
use App\Support\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;

/**
 * Order items that count as sold (non-cancelled orders created in a period), joined to their
 * product for its cost. Shared by Dashboard > Laporan penjualan and Keuangan so HPP and gross
 * profit are computed the same way everywhere.
 */
class SoldItems
{
    /** Cost per unit: the checkout snapshot, else the product's current cost for older orders. */
    public const UNIT_COST = 'coalesce(order_items.unit_cost, products.cost_price)';

    public static function query(Carbon $from, Carbon $to): Builder
    {
        return OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->leftJoin('products', 'products.id', '=', 'order_items.product_id')
            ->whereNull('orders.deleted_at')
            ->where('orders.status', '!=', OrderStatus::CANCELLED->value)
            ->where('orders.created_at', '>=', $from)
            ->where('orders.created_at', '<', $to);
    }
}
