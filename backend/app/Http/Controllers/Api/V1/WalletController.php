<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTopupResource;
use App\Http\Resources\WalletTransactionResource;
use App\Models\User;
use App\Models\WalletTopup;
use App\Services\MidtransService;
use App\Services\WalletService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use RuntimeException;

/** The buyer's own balance ("Saldo Inovasi"): summary, history and Midtrans top-ups. */
class WalletController extends Controller
{
    public function __construct(
        private readonly WalletService $wallet,
        private readonly MidtransService $midtrans,
    ) {}

    public function show(Request $request): JsonResponse
    {
        return ApiResponse::success($this->summary($request->user()), 'Wallet retrieved successfully.');
    }

    public function claimBonus(Request $request): JsonResponse
    {
        $transaction = $this->wallet->claimBonus($request->user());
        if (! $transaction) {
            return ApiResponse::error('Bonus saldo belanja sudah diklaim.', [], 422);
        }

        return ApiResponse::success([
            ...$this->summary($request->user()->fresh()),
            'claimed_amount' => (int) $transaction->amount,
        ], 'Bonus saldo belanja berhasil diklaim.');
    }

    private function summary(User $user): array
    {
        return [
            'balance' => (float) $user->wallet_balance,
            'topup_min' => (int) config('services.wallet.topup_min'),
            'topup_max' => (int) config('services.wallet.topup_max'),
            'max_balance' => (int) $this->wallet->maxBalance(),
            'bonus_max' => $this->wallet->bonusMax(),
            'bonus_available' => $this->wallet->bonusAvailable($user),
        ];
    }

    public function transactions(Request $request): JsonResponse
    {
        $transactions = $request->user()->walletTransactions()
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($transactions, WalletTransactionResource::class, 'Wallet transactions retrieved successfully.');
    }

    public function topup(Request $request): JsonResponse
    {
        $user = $request->user();
        $min = (int) config('services.wallet.topup_min');
        $max = (int) config('services.wallet.topup_max');

        $data = $request->validate([
            'amount' => ['required', 'integer', "min:$min", "max:$max"],
        ], [
            'amount.min' => 'Minimal top up Rp'.number_format($min, 0, ',', '.').'.',
            'amount.max' => 'Maksimal top up Rp'.number_format($max, 0, ',', '.').'.',
        ]);

        $cap = $this->wallet->maxBalance();
        if ($cap > 0 && (float) $user->wallet_balance + $data['amount'] > $cap) {
            return ApiResponse::error('Saldo setelah top up melebihi batas maksimum Rp'.number_format($cap, 0, ',', '.').'.', [], 422);
        }

        $topup = WalletTopup::create([
            'topup_number' => WalletTopup::NUMBER_PREFIX.now()->format('Ymd').'-'.Str::upper(Str::random(6)),
            'user_id' => $user->id,
            'amount' => $data['amount'],
        ]);

        try {
            $topup = $this->midtrans->createTopupTransaction($topup);
        } catch (RuntimeException $e) {
            $topup->update(['status' => WalletTopup::STATUS_FAILED]);

            return ApiResponse::error('Gagal membuat transaksi top up. Coba lagi.', [], 422);
        }

        return ApiResponse::success(new WalletTopupResource($topup), 'Top-up created.', [], 201);
    }

    /** Re-checks the top-up with Midtrans (the webhook may be late) and returns it. */
    public function topupStatus(Request $request, WalletTopup $topup): JsonResponse
    {
        if ($topup->user_id !== $request->user()->id) {
            return ApiResponse::error('This top-up does not belong to you.', [], 403);
        }

        try {
            $topup = $this->midtrans->syncTopupStatus($topup);
        } catch (RuntimeException $e) {
            report($e);
        }

        return ApiResponse::success(new WalletTopupResource($topup), 'Top-up status retrieved.');
    }
}
