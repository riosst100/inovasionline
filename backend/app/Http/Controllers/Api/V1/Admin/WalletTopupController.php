<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\WalletTopup;
use App\Models\WalletTransaction;
use App\Services\MidtransService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use RuntimeException;

/** Saldo Belanja > Top Up History: every top-up attempt across customers. */
class WalletTopupController extends Controller
{
    public const TIMEZONE = 'Asia/Jakarta';

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'in:pending,paid,failed,expired'],
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $base = WalletTopup::query()
            ->when($data['search'] ?? null, fn ($q, $search) => $q->where(fn ($q) => $q
                ->where('topup_number', 'ilike', "%{$search}%")
                ->orWhereHas('user', fn ($q) => $q
                    ->where('name', 'ilike', "%{$search}%")
                    ->orWhere('email', 'ilike', "%{$search}%")
                    ->orWhere('phone', 'ilike', "%{$search}%"))))
            ->when($data['date_from'] ?? null, fn ($q, $d) => $q->where('created_at', '>=', self::startOfDay($d)))
            ->when($data['date_to'] ?? null, fn ($q, $d) => $q->where('created_at', '<', self::startOfDay($d)->addDay()));

        // Summary covers the filtered range across all statuses so the status chips stay meaningful.
        $summary = (clone $base)
            ->selectRaw('status, COUNT(*) as count, COALESCE(SUM(amount), 0) as total')
            ->groupBy('status')
            ->get()
            ->mapWithKeys(fn ($r) => [$r->status => ['count' => (int) $r->count, 'total' => (float) $r->total]]);

        $topups = $base
            ->when($data['status'] ?? null, fn ($q, $status) => $q->where('status', $status))
            ->with('user:id,name,email,phone')
            ->latest()
            ->paginate($data['per_page'] ?? 20);

        $topups->through(fn (WalletTopup $t) => [
            'id' => $t->id,
            'topup_number' => $t->topup_number,
            'amount' => (float) $t->amount,
            'status' => $t->status,
            'payment_method' => $t->paymentMethodLabel(),
            'payment_expires_at' => $t->payment_expires_at,
            'paid_at' => $t->paid_at,
            'created_at' => $t->created_at,
            'user' => $t->user ? ['id' => $t->user->id, 'name' => $t->user->name, 'email' => $t->user->email, 'phone' => $t->user->phone] : null,
        ]);

        return ApiResponse::success($topups->items(), 'Top-ups retrieved successfully.', [
            'current_page' => $topups->currentPage(),
            'last_page' => $topups->lastPage(),
            'per_page' => $topups->perPage(),
            'total' => $topups->total(),
            'summary' => collect(['pending', 'paid', 'failed', 'expired'])
                ->mapWithKeys(fn ($s) => [$s => $summary[$s] ?? ['count' => 0, 'total' => 0.0]]),
        ]);
    }

    /** Detail with payment method and payer references; a running top-up is re-checked with Midtrans first. */
    public function show(WalletTopup $topup, MidtransService $midtrans): JsonResponse
    {
        try {
            $topup = $midtrans->refreshTopup($topup);
        } catch (RuntimeException $e) {
            report($e);
        }

        $topup->load(['user:id,name,email,phone,wallet_balance']);
        $transaction = $topup->status === WalletTopup::STATUS_PAID
            ? WalletTransaction::where('wallet_topup_id', $topup->id)->first()
            : null;

        return ApiResponse::success([
            'id' => $topup->id,
            'topup_number' => $topup->topup_number,
            'amount' => (float) $topup->amount,
            'status' => $topup->status,
            'payment_method' => $topup->paymentMethodLabel(),
            'payment_type' => $topup->midtrans_payment_type,
            'payment_fields' => $topup->paymentFields(),
            'payment_redirect_url' => $topup->status === WalletTopup::STATUS_PENDING ? $topup->payment_redirect_url : null,
            'payment_expires_at' => $topup->payment_expires_at,
            'paid_at' => $topup->paid_at,
            'created_at' => $topup->created_at,
            'updated_at' => $topup->updated_at,
            'balance_after' => $transaction ? (float) $transaction->balance_after : null,
            'user' => $topup->user ? [
                'id' => $topup->user->id,
                'name' => $topup->user->name,
                'email' => $topup->user->email,
                'phone' => $topup->user->phone,
                'balance' => (float) $topup->user->wallet_balance,
            ] : null,
        ], 'Top-up retrieved successfully.');
    }

    /** Start of a WIB calendar day, as the UTC instant stored in the database. */
    public static function startOfDay(string $date): Carbon
    {
        return Carbon::createFromFormat('Y-m-d', $date, self::TIMEZONE)->startOfDay()->utc();
    }
}
