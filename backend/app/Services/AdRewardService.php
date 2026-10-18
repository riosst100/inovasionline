<?php

namespace App\Services;

use App\Models\AdmobSetting;
use App\Models\AdReward;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;

/**
 * Rewarded-ad views that gate the one-time saldo bonus (admin: Iklan >
 * Adsense / Admob > "Wajib nonton iklan"). Views come in through AdMob's
 * server-side verification callback, so the app can't fake one.
 */
class AdRewardService
{
    /** A view must be this fresh to unlock the bonus. */
    public const VIEW_TTL_MINUTES = 60;

    public function bonusRequiresAd(): bool
    {
        return AdmobSetting::current()->bonusRequiresAd();
    }

    /** Stores a verified view. Idempotent per AdMob transaction id, since AdMob retries callbacks. */
    public function record(User $user, string $transactionId, string $adUnit, string $purpose = AdReward::PURPOSE_BONUS): AdReward
    {
        try {
            return AdReward::firstOrCreate(
                ['transaction_id' => $transactionId],
                ['user_id' => $user->id, 'ad_unit' => $adUnit, 'purpose' => $purpose],
            );
        } catch (UniqueConstraintViolationException) {
            return AdReward::where('transaction_id', $transactionId)->firstOrFail();
        }
    }

    /**
     * Marks one fresh, unused view as spent. Call inside the claim's transaction
     * so a failed claim gives the view back.
     *
     * @throws AdViewRequiredException when there is none (yet: AdMob's callback
     *         usually lands a few seconds after the ad closes)
     */
    public function consumeView(User $user): void
    {
        $view = AdReward::where('user_id', $user->id)
            ->where('purpose', AdReward::PURPOSE_BONUS)
            ->whereNull('consumed_at')
            ->where('created_at', '>=', now()->subMinutes(self::VIEW_TTL_MINUTES))
            ->oldest()
            ->lockForUpdate()
            ->first();

        if ($view === null) {
            throw new AdViewRequiredException('Tonton iklan sampai selesai untuk mengklaim bonus saldo.');
        }

        $view->update(['consumed_at' => now()]);
    }
}
