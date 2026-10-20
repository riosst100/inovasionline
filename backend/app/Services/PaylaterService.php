<?php

namespace App\Services;

use App\Models\OrderSetting;
use App\Models\User;
use App\Support\Enums\OrderStatus;

class PaylaterService
{
    public function __construct(private readonly CodVerificationService $verification) {}

    public function completedTransactions(User $user): int
    {
        return $user->orders()->where('status', OrderStatus::COMPLETED)->count();
    }

    /**
     * @return array{available: bool, reason: ?string, required_transactions: int, completed_transactions: int, requires_verification: bool}
     */
    public function eligibility(User $user): array
    {
        $required = (int) OrderSetting::current()->paylater_min_transactions;
        $completed = $this->completedTransactions($user);

        $reason = $completed < $required
            ? sprintf('Paylater dapat digunakan setelah %d transaksi selesai. Transaksi Anda: %d/%d.', $required, $completed, $required)
            : null;

        return [
            'available' => $reason === null,
            'reason' => $reason,
            'required_transactions' => $required,
            'completed_transactions' => $completed,
            // First use needs the one-time face verification (shared with COD).
            'requires_verification' => $reason === null && ! $this->verification->current($user),
        ];
    }

    /** @throws PaylaterNotEligibleException|PaylaterVerificationRequiredException */
    public function assertCanUse(User $user): void
    {
        $eligibility = $this->eligibility($user);

        if (! $eligibility['available']) {
            throw new PaylaterNotEligibleException($eligibility['reason']);
        }

        if ($eligibility['requires_verification']) {
            throw new PaylaterVerificationRequiredException;
        }
    }
}
