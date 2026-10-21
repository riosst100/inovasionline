<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Promosi > Gratis Ongkir: shipping is free when the order uses one of the
 * chosen payment methods AND one of the chosen shipping methods (and reaches
 * the minimum purchase, when one is set).
 */
class FreeShippingSetting extends Model
{
    protected $fillable = ['is_active', 'min_subtotal', 'payment_method_ids', 'shipping_method_ids'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'min_subtotal' => 'float',
            'payment_method_ids' => 'array',
            'shipping_method_ids' => 'array',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => false,
            'min_subtotal' => null,
            'payment_method_ids' => [],
            'shipping_method_ids' => [],
        ]);
    }

    /** Whether an order with these choices ships for free. */
    public function applies(string $paymentMethodId, string $shippingMethodId, float $subtotal): bool
    {
        return $this->is_active
            && in_array($paymentMethodId, $this->payment_method_ids ?? [], true)
            && in_array($shippingMethodId, $this->shipping_method_ids ?? [], true)
            && ($this->min_subtotal === null || $subtotal >= $this->min_subtotal);
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'min_subtotal' => $this->min_subtotal,
            'payment_method_ids' => array_values($this->payment_method_ids ?? []),
            'shipping_method_ids' => array_values($this->shipping_method_ids ?? []),
        ];
    }
}
