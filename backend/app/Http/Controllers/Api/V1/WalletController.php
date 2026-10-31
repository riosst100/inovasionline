<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTopupResource;
use App\Http\Resources\WalletTransactionResource;
use App\Models\AdReward;
use App\Models\User;
use App\Models\WalletTopup;
use App\Services\AdRewardService;
use App\Services\AdViewRequiredException;
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
        private readonly AdRewardService $adRewards,
    ) {}

    public function show(Request $request): JsonResponse
    {
        return ApiResponse::success($this->summary($request->user()), 'Wallet retrieved successfully.');
    }

    public function claimBonus(Request $request): JsonResponse
    {
        try {
            $transaction = $this->wallet->claimBonus($request->user());
        } catch (AdViewRequiredException $e) {
            // The app retries this for a few seconds while AdMob's callback is on its way.
            return ApiResponse::error($e->getMessage(), ['code' => ['ad_view_required']], 409);
        }
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
            'bonus_requires_ad' => $this->adRewards->bonusRequiresAd(),
        ];
    }

    /**
     * Debug builds show Google's sample ads, which never send an SSV callback;
     * this stands in for it. Disabled unless ADMOB_ALLOW_UNVERIFIED_REWARDS is
     * on, and always in production.
     */
    public function testAdView(Request $request): JsonResponse
    {
        abort_if(app()->isProduction() || ! config('services.admob.allow_unverified_rewards'), 404);

        $this->adRewards->record($request->user(), 'test-'.Str::ulid(), 'test', AdReward::PURPOSE_BONUS);

        return ApiResponse::success(null, 'Test ad view recorded.');
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
