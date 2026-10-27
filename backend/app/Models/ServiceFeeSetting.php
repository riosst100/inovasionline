<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceFeeSetting extends Model
{
    protected $fillable = ['is_active', 'label', 'type', 'value', 'min_fee', 'max_fee', 'free_min_subtotal'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'value' => 'float',
            'min_fee' => 'float',
            'max_fee' => 'float',
            'free_min_subtotal' => 'float',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => false,
            'label' => 'Biaya Layanan',
            'type' => 'fixed',
            'value' => 0,
        ]);
    }

    /** Service fee (rupiah, rounded) charged on the given product subtotal. */
    public function calculate(float $subtotal): float
    {
        if (! $this->is_active || $this->value <= 0) {
            return 0.0;
        }

        // Free service fee once the product subtotal reaches the threshold.
        if ($this->free_min_subtotal !== null && $this->free_min_subtotal > 0 && $subtotal >= $this->free_min_subtotal) {
            return 0.0;
        }

        $fee = $this->type === 'percent' ? $subtotal * $this->value / 100 : $this->value;

        if ($this->min_fee !== null) {
            $fee = max($fee, $this->min_fee);
        }
        if ($this->max_fee !== null) {
            $fee = min($fee, $this->max_fee);
        }

        return round($fee);
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'label' => $this->label,
            'type' => $this->type,
            'value' => (float) $this->value,
            'min_fee' => $this->min_fee,
            'max_fee' => $this->max_fee,
            'free_min_subtotal' => $this->free_min_subtotal,
        ];
    }
}
