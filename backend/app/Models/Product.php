<?php

namespace App\Models;

use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Product extends Model
{
    use HasFactory, HasUlids, SoftDeletes;

    protected $fillable = [
        'category_id',
        'supplier_id',
        'brand_id',
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

    /** Buyers must never see the cost; admin endpoints read it explicitly. */
    protected $hidden = ['cost_price'];

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

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    public function warehouses(): BelongsToMany
    {
        return $this->belongsToMany(Warehouse::class, 'product_warehouse_stocks')
            ->withPivot('quantity')
            ->withTimestamps();
    }

    /**
     * Total stock over all warehouses (read-only; write it through
     * ProductStockService). Lists should use withStock() to avoid one query per product.
     */
    protected function stock(): Attribute
    {
        return Attribute::get(function (): int {
            if (array_key_exists('stock_total', $this->attributes)) {
                return (int) $this->attributes['stock_total'];
            }
            if ($this->relationLoaded('warehouses')) {
                return (int) $this->warehouses->sum('pivot.quantity');
            }

            return (int) $this->warehouses()->sum('product_warehouse_stocks.quantity');
        });
    }

    /** Slug from the name, suffixed until unique (soft-deleted products included). */
    public static function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'produk';
        $slug = $base;
        for ($i = 1; static::withTrashed()->where('slug', $slug)->exists(); $i++) {
            $slug = "{$base}-{$i}";
        }

        return $slug;
    }

    public function scopeWithStock(Builder $query): void
    {
        $query->withSum('warehouses as stock_total', 'product_warehouse_stocks.quantity');
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
        return $this->belongsToMany(Promotion::class, 'promotion_products')
            ->using(PromotionProduct::class)
            ->withPivot('flash_sale_price');
    }

    /**
     * Price a buyer pays right now for the base product (no variant):
     * a running flash sale wins over sale_price, which wins over regular_price.
     */
    public function currentPrice(): float
    {
        return app(\App\Services\FlashSalePricing::class)->priceFor($this->id)
            ?? (float) ($this->sale_price ?? $this->regular_price);
    }

    public function posts(): BelongsToMany
    {
        return $this->belongsToMany(Post::class, 'post_products');
    }
}
