<?php

namespace App\Models;

use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Enums\ShippingMethodType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

class Order extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'order_number',
        'user_id',
        'driver_id',
        'payment_method_id',
        'shipping_method_id',
        'delivery_schedule_id',
        'promotion_id',
        'subtotal',
        'discount_total',
        'shipping_fee',
        'service_fee',
        'tax_total',
        'grand_total',
        'status',
        'payment_status',
        'payment_token',
        'payment_redirect_url',
        'payment_expires_at',
        'midtrans_order_id',
        'midtrans_transaction_id',
        'midtrans_payment_type',
        'paid_at',
        'delivery_method',
        'delivery_address',
        'delivery_date',
        'delivery_slot',
        'customer_notes',
        'admin_notes',
        'status_history',
        'accepted_at',
        'completed_at',
        'cancelled_at',
        'cancel_hold_started_at',
        'cancel_declined_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'subtotal' => 'decimal:2',
            'discount_total' => 'decimal:2',
            'shipping_fee' => 'decimal:2',
            'service_fee' => 'decimal:2',
            'tax_total' => 'decimal:2',
            'grand_total' => 'decimal:2',
            'delivery_address' => 'array',
            'delivery_date' => 'date',
            'delivery_slot' => 'array',
            'status_history' => 'array',
            'payment_expires_at' => 'datetime',
            'paid_at' => 'datetime',
            'accepted_at' => 'datetime',
            'completed_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'cancel_hold_started_at' => 'datetime',
            'cancel_declined_at' => 'datetime',
        ];
    }


    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function deliverySchedule(): BelongsTo
    {
        return $this->belongsTo(DeliverySchedule::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'driver_id');
    }

    public function paymentMethod(): BelongsTo
    {
        return $this->belongsTo(PaymentMethod::class);
    }

    public function shippingMethod(): BelongsTo
    {
        return $this->belongsTo(ShippingMethod::class);
    }

    public function promotion(): BelongsTo
    {
        return $this->belongsTo(Promotion::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /**
     * @var array<string, list<string>>
     */
    private const TRANSITIONS = [
        // pending -> processing happens automatically once an online payment settles.
        'pending' => ['processing', 'cancelled'],
        'processing' => ['ready', 'cancelled'],
        'ready' => ['on_delivery'],
        'on_delivery' => ['completed'],
        'completed' => [],
        'cancelled' => [],
    ];

    public function canTransitionTo(OrderStatus $next): bool
    {
        // Store pickup has no courier leg: the buyer collects it, so ready goes straight to completed.
        if ($this->status === OrderStatus::READY && $this->isStorePickup()) {
            return $next === OrderStatus::COMPLETED;
        }

        return in_array($next->value, self::TRANSITIONS[$this->status->value] ?? [], true);
    }

    public function isStorePickup(): bool
    {
        return $this->delivery_method === ShippingMethodType::STORE_PICKUP->value;
    }

    /**
     * Longest the buyer may keep the cancel confirmation open; an abandoned hold
     * (app closed mid-dialog) counts as backing out.
     */
    public const BUYER_CANCEL_MAX_HOLD_SECONDS = 120;

    /**
     * Last moment the buyer may cancel a processing order: the admin-set window counted
     * from when preparation started; while on hold, the end of the hold. Null when no
     * deadline applies.
     */
    public function buyerCancelDeadline(): ?Carbon
    {
        if ($this->status !== OrderStatus::PROCESSING) {
            return null;
        }

        if ($this->cancel_declined_at !== null) {
            return $this->cancel_declined_at;
        }

        if ($this->cancel_hold_started_at !== null) {
            return $this->cancel_hold_started_at->copy()->addSeconds(self::BUYER_CANCEL_MAX_HOLD_SECONDS);
        }

        return $this->cancelWindowEnd();
    }

    /** Seconds the countdown shows: frozen while on hold. Null when no deadline applies. */
    public function buyerCancelSecondsLeft(): ?int
    {
        if ($this->buyerCancelDeadline() === null) {
            return null;
        }

        if (! $this->buyerCanCancel()) {
            return 0;
        }

        $from = $this->isCancelOnHold() ? $this->cancel_hold_started_at : now();

        return max(0, $this->cancelWindowEnd()->getTimestamp() - $from->getTimestamp());
    }

    public function isCancelOnHold(): bool
    {
        return $this->status === OrderStatus::PROCESSING
            && $this->cancel_declined_at === null
            && $this->cancel_hold_started_at !== null
            && now()->lessThan($this->cancel_hold_started_at->copy()->addSeconds(self::BUYER_CANCEL_MAX_HOLD_SECONDS));
    }

    public function buyerCanCancel(): bool
    {
        if (! $this->canTransitionTo(OrderStatus::CANCELLED)) {
            return false;
        }

        $deadline = $this->buyerCancelDeadline();

        return $deadline === null || now()->lessThan($deadline);
    }

    /** Freezes the countdown while the buyer reads the cancel confirmation. */
    public function startCancelHold(): void
    {
        if ($this->status !== OrderStatus::PROCESSING || $this->cancel_hold_started_at !== null) {
            return;
        }

        $this->update(['cancel_hold_started_at' => now()]);
    }

    /** The buyer backed out of cancelling: the order carries on and can no longer be cancelled. */
    public function declineCancel(): void
    {
        if ($this->status !== OrderStatus::PROCESSING || $this->cancel_declined_at !== null) {
            return;
        }

        $this->update(['cancel_declined_at' => now()]);
    }

    /** Preparation start + admin window. */
    private function cancelWindowEnd(): Carbon
    {
        $startedAt = collect($this->status_history ?? [])
            ->where('status', OrderStatus::PROCESSING->value)
            ->pluck('at')
            ->last();

        $start = $startedAt ? Carbon::parse($startedAt) : ($this->paid_at ?? $this->created_at);

        return Carbon::instance($start)->addSeconds(OrderSetting::current()->buyer_cancel_window_seconds);
    }
}
