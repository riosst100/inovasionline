<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppInstall;
use App\Models\Employee;
use App\Models\Product;
use App\Models\Promotion;
use App\Models\SupplierBill;
use App\Models\User;
use App\Models\WalletTopup;
use App\Support\Enums\PromotionType;
use App\Support\Enums\UserRole;
use App\Support\Permissions\AdminMenu;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Dashboard summary grouped like the sidebar sections (AdminMenu). Every card belongs to a menu and
 * is only computed and returned when the admin may view that menu; empty sections are dropped.
 * "Today" and "this month" are WIB, like the sales report.
 */
class DashboardOverviewController extends Controller
{
    private const TIMEZONE = WalletTopupController::TIMEZONE;

    /** Live product stock: the sum over all warehouses. */
    private const STOCK = '(select coalesce(sum(quantity), 0) from product_warehouse_stocks where product_id = products.id)';

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $cards = $this->cards();

        $sections = [];
        foreach (AdminMenu::sections() as $title => $menus) {
            $items = [];
            foreach ($menus as [$menu]) {
                if (isset($cards[$menu]) && AdminMenu::canView($user, $menu)) {
                    foreach ($cards[$menu]() as $card) {
                        $items[] = ['menu' => $menu, 'money' => false, 'hint' => null, 'alert' => false, ...$card];
                    }
                }
            }
            if ($items) {
                $sections[] = ['title' => $title, 'cards' => $items];
            }
        }

        return ApiResponse::success(['sections' => $sections], 'Dashboard overview retrieved successfully.');
    }

    /** Menu key => closure returning its cards (lazy, so unpermitted menus are never queried). */
    private function cards(): array
    {
        $todayDate = now(self::TIMEZONE)->toDateString();
        $today = WalletTopupController::startOfDay($todayDate);
        $monthDate = now(self::TIMEZONE)->startOfMonth()->toDateString();
        $month = WalletTopupController::startOfDay($monthDate);

        // Orders have no cards: the dashboard shows the instant / scheduled order panels instead.
        return [
            'customers' => fn () => [
                [
                    'label' => 'Pengguna terdaftar',
                    'value' => User::query()->where('role', UserRole::CUSTOMER)->count(),
                    'hint' => '+'.User::query()->where('role', UserRole::CUSTOMER)->where('created_at', '>=', $today)->count().' hari ini',
                ],
                [
                    'label' => 'Online sekarang',
                    'value' => AppInstall::query()->where('last_seen_at', '>=', now()->subMinutes(AppInstall::ONLINE_MINUTES))->count(),
                    'hint' => 'Aktif '.AppInstall::ONLINE_MINUTES.' menit terakhir',
                ],
            ],
            'wallets' => fn () => [
                ['label' => 'Total saldo pengguna', 'value' => (float) User::query()->sum('wallet_balance'), 'money' => true, 'hint' => 'Dana pengguna yang tersimpan'],
            ],
            'wallet_topups' => function () use ($today) {
                $paid = WalletTopup::query()->where('status', WalletTopup::STATUS_PAID)->where('paid_at', '>=', $today);

                return [
                    ['label' => 'Top up hari ini', 'value' => (float) (clone $paid)->sum('amount'), 'money' => true, 'hint' => $paid->count().' transaksi berhasil'],
                ];
            },
            'products' => function () {
                $noCost = Product::query()->where('status', 'active')->whereNull('cost_price')->count();

                return [
                    ['label' => 'Produk aktif', 'value' => Product::query()->where('status', 'active')->count()],
                    ['label' => 'Tanpa harga modal', 'value' => $noCost, 'hint' => 'Produk aktif, laba belum akurat', 'alert' => $noCost > 0],
                ];
            },
            'product_stocks' => function () {
                $active = fn () => Product::query()->where('status', 'active');
                $out = $active()->whereRaw(self::STOCK.' = 0')->count();
                $low = $active()->where('min_stock', '>', 0)->whereRaw(self::STOCK.' > 0')->whereRaw(self::STOCK.' <= min_stock')->count();

                return [
                    ['label' => 'Stok habis', 'value' => $out, 'hint' => 'Produk aktif', 'alert' => $out > 0],
                    ['label' => 'Stok menipis', 'value' => $low, 'hint' => 'Di bawah stok minimum', 'alert' => $low > 0],
                ];
            },
            'flash_sales' => fn () => [
                [
                    'label' => 'Flash sale berjalan',
                    'value' => Promotion::query()
                        ->where('type', PromotionType::FLASH_SALE)
                        ->where('is_active', true)
                        ->where('starts_at', '<=', now())
                        ->where('ends_at', '>=', now())
                        ->count(),
                ],
            ],
            'employees' => fn () => [
                ['label' => 'Karyawan aktif', 'value' => Employee::query()->where('is_active', true)->count()],
            ],
            'purchases' => function () {
                $unpaid = SupplierBill::query()->unpaid();
                $overdue = SupplierBill::query()->overdue();
                $overdueCount = (clone $overdue)->count();

                return [
                    ['label' => 'Tagihan belum dibayar', 'value' => (float) (clone $unpaid)->sum('amount'), 'money' => true, 'hint' => $unpaid->count().' tagihan'],
                    [
                        'label' => 'Lewat jatuh tempo',
                        'value' => (float) $overdue->sum('amount'),
                        'money' => true,
                        'hint' => $overdueCount.' tagihan',
                        'alert' => $overdueCount > 0,
                    ],
                ];
            },
            'cashflow' => function () use ($monthDate, $todayDate) {
                $totals = CompanyTransactionController::manualTotals($monthDate, $todayDate);

                return [
                    ['label' => 'Biaya operasional bulan ini', 'value' => $totals['expense'], 'money' => true, 'hint' => 'Dicatat di Cashflow'],
                    ['label' => 'Pemasukan lain bulan ini', 'value' => $totals['income'], 'money' => true, 'hint' => 'Dicatat di Cashflow'],
                ];
            },
            'finance_report' => fn () => [
                [
                    'label' => 'Laba bersih bulan ini',
                    'value' => FinanceController::netIncome($month, now()->addSecond(), $monthDate, $todayDate),
                    'money' => true,
                    'hint' => 'Setelah biaya operasional',
                ],
            ],
        ];
    }
}
