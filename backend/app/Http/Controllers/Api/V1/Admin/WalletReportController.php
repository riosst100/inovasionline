<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\WalletTopup;
use App\Models\WalletTransaction;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Saldo Belanja > Laporan: total balance held for all customers, plus the money
 * that came in (top up, refund, bonus, …) and went out (payments, …) in a period.
 */
class WalletReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'direction' => ['nullable', 'in:in,out'],
            'type' => ['nullable', 'in:topup,payment,refund,adjustment,bonus,ad_chest'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $from = isset($data['date_from']) ? WalletTopupController::startOfDay($data['date_from']) : null;
        $to = isset($data['date_to']) ? WalletTopupController::startOfDay($data['date_to'])->addDay() : null;

        $period = fn (): Builder => WalletTransaction::query()
            ->when($from, fn ($q) => $q->where('wallet_transactions.created_at', '>=', $from))
            ->when($to, fn ($q) => $q->where('wallet_transactions.created_at', '<', $to));

        $byType = $period()
            ->selectRaw('type, SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credit, SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END) as debit, COUNT(*) as count')
            ->groupBy('type')
            ->get();

        $income = $byType->where('credit', '>', 0)->map(fn ($r) => ['type' => $r->type, 'total' => (float) $r->credit])->values();
        $expense = $byType->where('debit', '>', 0)->map(fn ($r) => ['type' => $r->type, 'total' => (float) $r->debit])->values();
        $totalIn = (float) $income->sum('total');
        $totalOut = (float) $expense->sum('total');

        // The ledger is the source of truth, so the balance at any point is the sum before it.
        $opening = $from ? (float) WalletTransaction::where('created_at', '<', $from)->sum('amount') : 0.0;
        $closing = $to ? (float) WalletTransaction::where('created_at', '<', $to)->sum('amount') : null;

        $channel = "COALESCE(wallet_topups.payment_details->'va_numbers'->0->>'bank', wallet_topups.payment_details->>'store', wallet_topups.payment_details->>'issuer', wallet_topups.payment_details->>'bank', CASE WHEN wallet_topups.payment_details->>'permata_va_number' IS NOT NULL THEN 'permata' END)";
        $byMethod = $period()
            ->join('wallet_topups', 'wallet_topups.id', '=', 'wallet_transactions.wallet_topup_id')
            ->where('wallet_transactions.type', WalletTransaction::TYPE_TOPUP)
            ->selectRaw("wallet_topups.midtrans_payment_type as payment_type, $channel as channel, SUM(wallet_transactions.amount) as total, COUNT(*) as count")
            ->groupByRaw("wallet_topups.midtrans_payment_type, $channel")
            ->get()
            ->groupBy(fn ($r) => self::methodLabel($r->payment_type, $r->channel))
            ->map(fn ($rows, $method) => ['method' => $method, 'total' => (float) $rows->sum('total'), 'count' => (int) $rows->sum('count')])
            ->sortByDesc('total')
            ->values();

        $transactions = $period()
            ->when($data['direction'] ?? null, fn ($q, $d) => $q->where('amount', $d === 'in' ? '>' : '<', 0))
            ->when($data['type'] ?? null, fn ($q, $t) => $q->where('type', $t))
            ->when($data['search'] ?? null, fn ($q, $search) => $q->whereHas('user', fn ($q) => $q
                ->where('name', 'ilike', "%{$search}%")
                ->orWhere('email', 'ilike', "%{$search}%")
                ->orWhere('phone', 'ilike', "%{$search}%")))
            ->with(['user:id,name,email,phone', 'order:id,order_number', 'adminUser:id,name', 'topup:id,topup_number,midtrans_payment_type,payment_details'])
            ->latest()
            ->paginate($data['per_page'] ?? 25);

        $transactions->through(fn (WalletTransaction $t) => [
            'id' => $t->id,
            'type' => $t->type,
            'amount' => (float) $t->amount,
            'balance_after' => (float) $t->balance_after,
            'description' => $t->description,
            'payment_method' => $t->topup?->paymentMethodLabel(),
            'topup' => $t->topup ? ['id' => $t->topup->id, 'topup_number' => $t->topup->topup_number] : null,
            'order' => $t->order ? ['id' => $t->order->id, 'order_number' => $t->order->order_number] : null,
            'admin' => $t->adminUser ? ['id' => $t->adminUser->id, 'name' => $t->adminUser->name] : null,
            'user' => $t->user ? ['id' => $t->user->id, 'name' => $t->user->name, 'email' => $t->user->email, 'phone' => $t->user->phone] : null,
            'created_at' => $t->created_at,
        ]);

        $customers = User::where('role', UserRole::CUSTOMER);

        return ApiResponse::success([
            'total_balance' => (float) (clone $customers)->sum('wallet_balance'),
            'customers_with_balance' => (clone $customers)->where('wallet_balance', '>', 0)->count(),
            'period' => [
                'opening_balance' => $opening,
                'total_in' => $totalIn,
                'total_out' => $totalOut,
                'net' => $totalIn - $totalOut,
                'closing_balance' => $closing ?? $opening + $totalIn - $totalOut,
            ],
            'income_by_type' => $income,
            'expense_by_type' => $expense,
            'income_by_method' => $byMethod,
            'transactions' => $transactions->items(),
        ], 'Wallet report retrieved successfully.', [
            'current_page' => $transactions->currentPage(),
            'last_page' => $transactions->lastPage(),
            'per_page' => $transactions->perPage(),
            'total' => $transactions->total(),
        ]);
    }

    private static function methodLabel(?string $type, ?string $channel): string
    {
        $topup = new WalletTopup(['midtrans_payment_type' => $type]);
        $details = match ($type) {
            'bank_transfer' => ['va_numbers' => [['bank' => $channel]]],
            'cstore' => ['store' => $channel],
            'qris', 'other_qris' => ['issuer' => $channel],
            'credit_card' => ['bank' => $channel],
            default => [],
        };
        $topup->payment_details = $channel ? $details : null;

        return $topup->paymentMethodLabel() ?? 'Belum diketahui';
    }
}
