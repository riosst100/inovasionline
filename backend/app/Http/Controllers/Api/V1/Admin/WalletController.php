<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTransactionResource;
use App\Models\User;
use App\Services\WalletService;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/** Buyer balances: overview, per-customer ledger and manual adjustments. */
class WalletController extends Controller
{
    public function __construct(private readonly WalletService $wallet) {}

    public function index(Request $request): JsonResponse
    {
        $users = User::query()
            ->where('role', '!=', UserRole::PLATFORM_ADMIN->value)
            ->when($request->string('search')->toString(), fn ($q, $search) => $q->where(fn ($q) => $q
                ->where('name', 'ilike', "%{$search}%")
                ->orWhere('email', 'ilike', "%{$search}%")
                ->orWhere('phone', 'ilike', "%{$search}%")))
            ->when($request->boolean('has_balance'), fn ($q) => $q->where('wallet_balance', '>', 0))
            ->orderByDesc('wallet_balance')
            ->paginate($request->integer('per_page', 20), ['id', 'name', 'email', 'phone', 'wallet_balance']);

        $users->through(fn (User $u) => [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'phone' => $u->phone,
            'balance' => (float) $u->wallet_balance,
        ]);

        return ApiResponse::success($users->items(), 'Wallets retrieved successfully.', [
            'current_page' => $users->currentPage(),
            'last_page' => $users->lastPage(),
            'per_page' => $users->perPage(),
            'total' => $users->total(),
            'total_balance' => (float) User::where('role', UserRole::CUSTOMER)->sum('wallet_balance'),
        ]);
    }

    public function show(Request $request, User $user): JsonResponse
    {
        $transactions = $user->walletTransactions()
            ->with('adminUser:id,name')
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::success([
            'user' => ['id' => $user->id, 'name' => $user->name, 'email' => $user->email, 'phone' => $user->phone],
            'balance' => (float) $user->wallet_balance,
            'transactions' => WalletTransactionResource::collection($transactions->items()),
        ], 'Wallet retrieved successfully.', [
            'current_page' => $transactions->currentPage(),
            'last_page' => $transactions->lastPage(),
            'total' => $transactions->total(),
        ]);
    }

    public function adjust(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'not_in:0', 'between:-100000000,100000000'],
            'description' => ['required', 'string', 'max:255'],
        ], [
            'amount.not_in' => 'Nominal penyesuaian tidak boleh 0.',
            'description.required' => 'Alasan penyesuaian wajib diisi.',
        ]);

        try {
            $transaction = $this->wallet->adjust($user, (float) $data['amount'], $data['description'], $request->user());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success([
            'balance' => (float) $transaction->balance_after,
            'transaction' => new WalletTransactionResource($transaction->load('adminUser:id,name')),
        ], 'Saldo berhasil disesuaikan.');
    }
}
