<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\CompanyTransaction;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Keuangan > Cashflow: the company cash book. Combines, by the day money moved (WIB):
 *  - paid orders (income, by orders.paid_at; refunded orders drop out),
 *  - paid supplier bills (expense, by supplier_bills.paid_at),
 *  - manual entries in company_transactions (operating costs, other income).
 */
class CompanyTransactionController extends Controller
{
    private const TIMEZONE = WalletTopupController::TIMEZONE;

    private const MAX_DAYS = 366;

    public const SOURCES = ['order', 'supplier_bill', 'manual'];

    private const DEFAULT_CATEGORIES = [
        CompanyTransaction::TYPE_EXPENSE => [
            'Gaji Karyawan', 'Sewa', 'Listrik & Air', 'Internet & Telepon', 'Iklan & Promosi',
            'Bensin & Transport', 'Perlengkapan', 'Pajak', 'Lainnya',
        ],
        CompanyTransaction::TYPE_INCOME => ['Pemasukan Lain', 'Modal', 'Bunga Bank'],
    ];

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'type' => ['nullable', Rule::in([CompanyTransaction::TYPE_INCOME, CompanyTransaction::TYPE_EXPENSE])],
            'source' => ['nullable', Rule::in(self::SOURCES)],
            'category' => ['nullable', 'string', 'max:60'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $now = now(self::TIMEZONE);
        $fromDate = $data['date_from'] ?? $now->copy()->startOfMonth()->toDateString();
        $toDate = $data['date_to'] ?? $now->toDateString();
        $from = WalletTopupController::startOfDay($fromDate);
        $to = WalletTopupController::startOfDay($toDate)->addDay();
        if ($from->diffInDays($to) > self::MAX_DAYS) {
            return ApiResponse::error('Rentang tanggal maksimal '.self::MAX_DAYS.' hari.', [], 422);
        }

        $entries = fn () => DB::query()->fromSub($this->entries($from, $to, $fromDate, $toDate), 'entries');

        $byCategory = $entries()
            ->selectRaw('type, category, sum(amount) as total, count(*) as count')
            ->groupBy('type', 'category')
            ->orderByDesc('total')
            ->get();

        $income = (float) $byCategory->where('type', CompanyTransaction::TYPE_INCOME)->sum('total');
        $expense = (float) $byCategory->where('type', CompanyTransaction::TYPE_EXPENSE)->sum('total');

        $page = $entries()
            ->when($data['type'] ?? null, fn ($q, $type) => $q->where('type', $type))
            ->when($data['source'] ?? null, fn ($q, $source) => $q->where('source', $source))
            ->when($data['category'] ?? null, fn ($q, $category) => $q->where('category', $category))
            ->orderByDesc('date')
            ->orderByDesc('sort_at')
            ->paginate($data['per_page'] ?? 25);

        return ApiResponse::success([
            'period' => ['date_from' => $fromDate, 'date_to' => $toDate],
            'summary' => ['income' => $income, 'expense' => $expense, 'net' => $income - $expense],
            'by_category' => $byCategory->map(fn ($r) => [
                'type' => $r->type,
                'category' => $r->category,
                'total' => (float) $r->total,
                'count' => (int) $r->count,
            ])->values(),
            'categories' => $this->categories(),
            'entries' => collect($page->items())->map(fn ($r) => [
                'source' => $r->source,
                'id' => $r->id,
                'type' => $r->type,
                'category' => $r->category,
                'amount' => (float) $r->amount,
                'date' => $r->date,
                'description' => $r->description,
                'reference' => $r->reference,
                'employee_id' => $r->employee_id,
                'employee_name' => $r->employee_name,
            ]),
        ], 'Company cash book retrieved successfully.', [
            'current_page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
            'per_page' => $page->perPage(),
            'total' => $page->total(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $transaction = CompanyTransaction::create($request->validate($this->rules()));

        return ApiResponse::success($transaction, 'Transaksi berhasil dicatat.', [], 201);
    }

    public function update(Request $request, CompanyTransaction $companyTransaction): JsonResponse
    {
        // Full replace: optional fields left out are cleared, not kept.
        $companyTransaction->update(['description' => null, 'employee_id' => null, ...$request->validate($this->rules())]);

        return ApiResponse::success($companyTransaction->fresh(), 'Transaksi berhasil diperbarui.');
    }

    public function destroy(CompanyTransaction $companyTransaction): JsonResponse
    {
        $companyTransaction->delete();

        return ApiResponse::success(null, 'Transaksi berhasil dihapus.');
    }

    /** Manual entries of a period by type, for Laporan Keuangan's net income. */
    public static function manualTotals(string $fromDate, string $toDate): array
    {
        $rows = CompanyTransaction::query()
            ->whereBetween('transaction_date', [$fromDate, $toDate])
            ->selectRaw('type, sum(amount) as total')
            ->groupBy('type')
            ->pluck('total', 'type');

        return [
            'income' => (float) ($rows[CompanyTransaction::TYPE_INCOME] ?? 0),
            'expense' => (float) ($rows[CompanyTransaction::TYPE_EXPENSE] ?? 0),
        ];
    }

    private function entries(Carbon $from, Carbon $to, string $fromDate, string $toDate): Builder
    {
        $local = fn (string $column) => "({$column} at time zone 'UTC' at time zone '".self::TIMEZONE."')::date";

        $orders = DB::table('orders')
            ->leftJoin('users', 'users.id', '=', 'orders.user_id')
            ->whereNull('orders.deleted_at')
            ->where('orders.payment_status', PaymentStatus::PAID->value)
            ->where('orders.paid_at', '>=', $from)
            ->where('orders.paid_at', '<', $to)
            ->selectRaw("
                'order' as source, orders.id as id, 'income' as type, 'Penjualan' as category,
                orders.grand_total as amount, {$local('orders.paid_at')} as date, orders.paid_at as sort_at,
                users.name as description, orders.order_number as reference,
                null::text as employee_id, null::text as employee_name
            ");

        $bills = DB::table('supplier_bills')
            ->join('suppliers', 'suppliers.id', '=', 'supplier_bills.supplier_id')
            ->where('supplier_bills.paid_at', '>=', $from)
            ->where('supplier_bills.paid_at', '<', $to)
            ->selectRaw("
                'supplier_bill', supplier_bills.id, 'expense', 'Pembayaran Supplier',
                supplier_bills.amount, {$local('supplier_bills.paid_at')}, supplier_bills.paid_at,
                suppliers.name, supplier_bills.bill_number, null::text, null::text
            ");

        $manual = DB::table('company_transactions')
            ->leftJoin('employees', 'employees.id', '=', 'company_transactions.employee_id')
            ->whereBetween('company_transactions.transaction_date', [$fromDate, $toDate])
            ->selectRaw("
                'manual', company_transactions.id, company_transactions.type, company_transactions.category,
                company_transactions.amount, company_transactions.transaction_date, company_transactions.created_at,
                company_transactions.description, null::text, company_transactions.employee_id::text, employees.name
            ");

        return $orders->unionAll($bills)->unionAll($manual);
    }

    /** @return array<string, list<string>> Suggestions: defaults plus categories already used. */
    private function categories(): array
    {
        $used = CompanyTransaction::query()->select('type', 'category')->distinct()->get()->groupBy('type');

        return collect(self::DEFAULT_CATEGORIES)
            ->map(fn ($defaults, $type) => collect($defaults)->merge($used->get($type)?->pluck('category') ?? [])->unique()->values()->all())
            ->all();
    }

    private function rules(): array
    {
        return [
            'type' => ['required', Rule::in([CompanyTransaction::TYPE_INCOME, CompanyTransaction::TYPE_EXPENSE])],
            'category' => ['required', 'string', 'max:60'],
            'amount' => ['required', 'numeric', 'min:1'],
            'transaction_date' => ['required', 'date_format:Y-m-d'],
            'description' => ['nullable', 'string', 'max:255'],
            'employee_id' => ['nullable', 'exists:employees,id'],
        ];
    }
}
