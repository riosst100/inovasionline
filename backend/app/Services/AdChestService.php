<?php

namespace App\Services;

use App\Models\AdChest;
use App\Models\AdChestSetting;
use App\Models\AdmobSetting;
use App\Models\AdReward;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * The home screen's "Peti Hadiah" (admin: Iklan > Peti Hadiah): each chest is
 * opened by one verified rewarded-ad view and pays a random saldo belanja
 * amount. The daily chest count resets at midnight WIB.
 */
class AdChestService
{
    private const TIMEZONE = 'Asia/Jakarta';

    public function __construct(private readonly WalletService $wallet) {}

    /** For the home card; null while the chest is off (the card hides). */
    public function status(User $user): ?array
    {
        $setting = AdChestSetting::current();
        if (! $this->enabled($setting)) {
            return null;
        }

        $opened = AdChest::where('user_id', $user->id)->where('created_at', '>=', $this->startOfToday())->count();

        return [
            'opened_today' => $opened,
            'chests_per_day' => (int) $setting->chests_per_day,
            'max_amount' => $setting->maxAmount(),
            'done_today' => $opened >= $setting->chests_per_day,
            // Budget used up: the app stops offering chests for today.
            'sold_out' => $this->budgetLeft($setting) === 0,
        ];
    }

    /**
     * Opens a chest with a verified view and returns the amount credited.
     *
     * @throws AdViewRequiredException when there is no unused view (yet: AdMob's
     *         callback usually lands a few seconds after the ad closes)
     * @throws RuntimeException when the chest is off or today's chests are used up
     */
    public function open(User $user): int
    {
        return DB::transaction(function () use ($user) {
            // Serialises one user's opens so two taps can't spend the same views.
            $locked = User::whereKey($user->id)->lockForUpdate()->firstOrFail();

            $setting = AdChestSetting::current();
            if (! $this->enabled($setting)) {
                throw new RuntimeException('Peti hadiah sedang tidak tersedia.');
            }

            $opened = AdChest::where('user_id', $locked->id)->where('created_at', '>=', $this->startOfToday())->count();
            if ($opened >= $setting->chests_per_day) {
                throw new RuntimeException('Peti hadiah hari ini sudah habis. Kembali lagi besok!');
            }

            $view = $this->pendingViews($locked)->oldest()->first();
            if ($view === null) {
                throw new AdViewRequiredException('Tonton iklan sampai selesai untuk membuka peti.');
            }

            $amount = $setting->rollAmount();
            $left = $this->budgetLeft($setting);
            if ($left !== null) {
                // Past the budget the user still gets the smallest prize for the ad watched.
                $amount = max(min($amount, $left), $setting->minAmount());
            }

            $ledger = $this->wallet->creditAdChest($locked, $amount);
            AdChest::create(['user_id' => $locked->id, 'amount' => $amount, 'wallet_transaction_id' => $ledger->id]);
            $view->update(['consumed_at' => now()]);

            return $amount;
        });
    }

    /** Saldo paid out by chests today, all users. */
    public function paidToday(): int
    {
        return (int) AdChest::where('created_at', '>=', $this->startOfToday())->sum('amount');
    }

    private function enabled(AdChestSetting $setting): bool
    {
        $ads = AdmobSetting::current();

        return $setting->is_active
            && $setting->maxAmount() > 0
            && $ads->is_active
            && ($ads->android_rewarded_id || $ads->ios_rewarded_id);
    }

    /** Null without a budget, else what is left of it today (never below 0). */
    private function budgetLeft(AdChestSetting $setting): ?int
    {
        if ($setting->daily_budget <= 0) {
            return null;
        }

        return max(0, $setting->daily_budget - $this->paidToday());
    }

    /** Today's verified chest views not yet spent on a chest (a view expires with the day). */
    private function pendingViews(User $user): Builder
    {
        return AdReward::where('user_id', $user->id)
            ->where('purpose', AdReward::PURPOSE_CHEST)
            ->whereNull('consumed_at')
            ->where('created_at', '>=', $this->startOfToday());
    }

    private function startOfToday(): Carbon
    {
        return Carbon::now(self::TIMEZONE)->startOfDay()->utc();
    }
}
