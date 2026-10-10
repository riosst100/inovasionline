<?php

namespace App\Models;

use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'store_id',
        'category_id',
        'name',
        'slug',
        'short_description',
        'description',
        'product_type',
        'regular_price',
        'sale_price',
        'cost_price',
        'is_taxable',
        'sku',
        'stock',
        'min_stock',
        'track_inventory',
        'weight',
        'length',
        'width',
        'height',
        'requires_shipping',
        'status',
        'available_start_at',
        'available_end_at',
        'meta_title',
        'meta_description',
    ];

    protected function casts(): array
    {
        return [
            'product_type' => ProductType::class,
            'status' => ProductStatus::class,
            'regular_price' => 'decimal:2',
            'sale_price' => 'decimal:2',
            'cost_price' => 'decimal:2',
            'is_taxable' => 'boolean',
            'track_inventory' => 'boolean',
            'requires_shipping' => 'boolean',
            'weight' => 'decimal:2',
            'length' => 'decimal:2',
            'width' => 'decimal:2',
            'height' => 'decimal:2',
            'available_start_at' => 'datetime',
            'available_end_at' => 'datetime',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function images(): HasMany
    {
        return $this->hasMany(ProductImage::class)->orderBy('sort_order');
    }

    public function primaryImage(): HasMany
    {
        return $this->hasMany(ProductImage::class)->where('is_primary', true);
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function searchResultClicks(): HasMany
    {
        return $this->hasMany(SearchResultClick::class);
    }

    public function promotions(): BelongsToMany
    {
        return $this->belongsToMany(Promotion::class, 'promotion_products')->using(PromotionProduct::class);
    }

    public function posts(): BelongsToMany
    {
        return $this->belongsToMany(Post::class, 'post_products');
    }
}
