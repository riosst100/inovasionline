<?php

namespace App\Models\Concerns;

/**
 * Random saldo amounts from admin-set tiers: a tier is picked by its weight (%),
 * then an amount inside it in multiples of step. Needs `tiers` and `step` attributes.
 */
trait RollsTiers
{
    /** @return list<array{from: int, to: int, weight: int}> usable tiers only */
    public function usableTiers(): array
    {
        return collect($this->tiers ?? [])
            ->map(fn ($t) => ['from' => (int) $t['from'], 'to' => (int) $t['to'], 'weight' => max(0, (int) $t['weight'])])
            ->filter(fn ($t) => $t['weight'] > 0 && $t['to'] >= $t['from'] && $t['from'] > 0)
            ->values()
            ->all();
    }

    /** The most a roll can give ("hingga ..."); 0 without usable tiers. */
    public function maxAmount(): int
    {
        return (int) collect($this->usableTiers())->max('to');
    }

    /** The least a roll can give; 0 without usable tiers. */
    public function minAmount(): int
    {
        return (int) collect($this->usableTiers())->min('from');
    }

    /** 0 when there is nothing to roll. */
    public function rollAmount(): int
    {
        $tiers = $this->usableTiers();
        $total = array_sum(array_column($tiers, 'weight'));
        if ($total <= 0) {
            return 0;
        }

        $roll = random_int(1, $total);
        foreach ($tiers as $tier) {
            $roll -= $tier['weight'];
            if ($roll <= 0) {
                break;
            }
        }

        // A multiple of the step inside the tier (falling back to its lower bound if none fits).
        $step = max(1, (int) $this->step);
        $first = (int) ceil($tier['from'] / $step);
        $last = (int) floor($tier['to'] / $step);

        return $first <= $last ? random_int($first, $last) * $step : $tier['from'];
    }

    protected function tiersPayload(): array
    {
        return array_map(fn ($t) => [
            'from' => (int) $t['from'],
            'to' => (int) $t['to'],
            'weight' => (int) $t['weight'],
        ], $this->tiers ?? []);
    }
}
