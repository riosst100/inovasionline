<?php

namespace App\Models;

use App\Support\Enums\StoreStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Laravolt\Indonesia\Models\City;

class Store extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'seller_id',
        'category_id',
        'name',
        'slug',
        'description',
        'business_type',
        'logo_path',
        'cover_path',
        'phone',
        'whatsapp',
        'email',
        'website',
        'address',
        'province',
        'city',
        'city_code',
        'district',
        'postal_code',
        'latitude',
        'longitude',
        'operating_hours',
        'social_links',
        'status',
        'delivery_available',
        'is_featured',
        'approved_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => StoreStatus::class,
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
            'operating_hours' => 'array',
            'social_links' => 'array',
            'delivery_available' => 'boolean',
            'is_featured' => 'boolean',
            'approved_at' => 'datetime',
        ];
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(Seller::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function cityRegion(): BelongsTo
    {
        return $this->belongsTo(City::class, 'city_code', 'code');
    }

    public function members(): HasMany
    {
        return $this->hasMany(StoreMember::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function promotions(): HasMany
    {
        return $this->hasMany(Promotion::class);
    }

    public function paymentMethods(): HasMany
    {
        return $this->hasMany(PaymentMethod::class);
    }

    public function shippingMethods(): HasMany
    {
        return $this->hasMany(ShippingMethod::class);
    }
}
