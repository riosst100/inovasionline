<?php

namespace App\Models;

use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Order extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'order_number',
        'store_id',
        'user_id',
        'payment_method_id',
        'shipping_method_id',
        'promotion_id',
        'subtotal',
        'discount_total',
        'shipping_fee',
        'tax_total',
        'grand_total',
        'status',
        'payment_status',
        'delivery_method',
        'delivery_address',
        'customer_notes',
        'seller_notes',
        'status_history',
        'accepted_at',
        'completed_at',
        'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'subtotal' => 'decimal:2',
            'discount_total' => 'decimal:2',
            'shipping_fee' => 'decimal:2',
            'tax_total' => 'decimal:2',
            'grand_total' => 'decimal:2',
            'delivery_address' => 'array',
            'status_history' => 'array',
            'accepted_at' => 'datetime',
            'completed_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
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
        'pending' => ['accepted', 'cancelled'],
        'accepted' => ['processing', 'cancelled'],
        'processing' => ['ready', 'cancelled'],
        'ready' => ['completed'],
        'completed' => [],
        'cancelled' => [],
    ];

    public function canTransitionTo(OrderStatus $next): bool
    {
        return in_array($next->value, self::TRANSITIONS[$this->status->value] ?? [], true);
    }
}
