<?php

namespace App\Services;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\User;
use App\Models\WalletBonusSetting;
use App\Models\WalletTopup;
use App\Models\WalletTransaction;
use App\Support\Enums\PaymentStatus;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * The only place that changes users.wallet_balance. Every change locks the user
 * row and writes a ledger entry in the same transaction, so the balance always
 * equals the sum of the ledger and can never go negative.
 */
class WalletService
{
    public function payForOrder(Order $order): WalletTransaction
    {
        return $this->apply(
            $order->user_id,
            WalletTransaction::TYPE_PAYMENT,
            -(float) $order->grand_total,
            "Pembayaran pesanan {$order->order_number}",
            ['order_id' => $order->id],
        );
    }

    /** Credits a paid order's total back. Idempotent: a second call returns the first refund. */
    public function refundOrder(Order $order): WalletTransaction
    {
        return DB::transaction(function () use ($order) {
            $existing = WalletTransaction::where('order_id', $order->id)
                ->where('type', WalletTransaction::TYPE_REFUND)
                ->first();

            if ($existing) {
                return $existing;
            }

            $transaction = $this->apply(
                $order->user_id,
                WalletTransaction::TYPE_REFUND,
                (float) $order->grand_total,
                "Pengembalian dana pesanan {$order->order_number}",
                ['order_id' => $order->id],
            );

            $order->update(['payment_status' => PaymentStatus::REFUNDED]);

            return $transaction;
        });
    }

    /** Credits a settled top-up once; later notifications for it are no-ops. */
    public function creditTopup(WalletTopup $topup): ?WalletTransaction
    {
        if (WalletTransaction::where('wallet_topup_id', $topup->id)->exists()) {
            return null;
        }

        return $this->apply(
            $topup->user_id,
            WalletTransaction::TYPE_TOPUP,
            (float) $topup->amount,
            "Top up saldo {$topup->topup_number}",
            ['wallet_topup_id' => $topup->id],
        );
    }

    public function adjust(User $user, float $amount, string $description, AdminUser $admin): WalletTransaction
    {
        if ($amount == 0.0) {
            throw new RuntimeException('Nominal penyesuaian tidak boleh 0.');
        }

        return $this->apply(
            $user->id,
            WalletTransaction::TYPE_ADJUSTMENT,
            $amount,
            $description,
            ['admin_user_id' => $admin->id],
        );
    }

    /** The most a bonus can be ("hingga ..."); 0 when bonuses are off. */
    public function bonusMax(): int
    {
        $setting = WalletBonusSetting::current();
        if (! $setting->is_active) {
            return 0;
        }

        return $setting->maxAmount();
    }

    public function bonusAvailable(User $user): bool
    {
        return $this->bonusMax() > 0 && $user->wallet_bonus_claimed_at === null;
    }

    /** Picks a tier by weight (admin: Promosi > Bonus Saldo Belanja), then an amount inside it. */
    public function rollBonusAmount(): int
    {
        $setting = WalletBonusSetting::current();

        return $setting->is_active ? $setting->rollAmount() : 0;
    }

    /**
     * Credits the one-time bonus. Returns null when it is disabled or already claimed.
     *
     * @throws AdViewRequiredException when admin requires a watched ad and none is verified yet
     */
    public function claimBonus(User $user): ?WalletTransaction
    {
        $amount = $this->rollBonusAmount();
        if ($amount <= 0) {
            return null;
        }

        return DB::transaction(function () use ($user, $amount) {
            $locked = User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            if ($locked->wallet_bonus_claimed_at !== null) {
                return null;
            }

            $ads = app(AdRewardService::class);
            if ($ads->bonusRequiresAd()) {
                $ads->consumeView($locked);
            }

            $locked->forceFill(['wallet_bonus_claimed_at' => now()])->save();

            return $this->apply($user->id, WalletTransaction::TYPE_BONUS, $amount, 'Bonus saldo belanja', []);
        });
    }

    public function maxBalance(): float
    {
        return (float) config('services.wallet.max_balance');
    }

    private function apply(string $userId, string $type, float $amount, string $description, array $refs): WalletTransaction
    {
        return DB::transaction(function () use ($userId, $type, $amount, $description, $refs) {
            $user = User::whereKey($userId)->lockForUpdate()->firstOrFail();
            $balance = round((float) $user->wallet_balance + $amount, 2);

            if ($balance < 0) {
                throw new RuntimeException('Saldo tidak cukup.');
            }

            // Only top-ups are capped; refunds and payments must always go through.
            if ($type === WalletTransaction::TYPE_TOPUP && $this->maxBalance() > 0 && $balance > $this->maxBalance()) {
                throw new RuntimeException('Saldo melebihi batas maksimum.');
            }

            $user->forceFill(['wallet_balance' => $balance])->save();

            return WalletTransaction::create([
                'user_id' => $userId,
                'type' => $type,
                'amount' => $amount,
                'balance_after' => $balance,
                'description' => $description,
                ...$refs,
            ]);
        });
    }
}
