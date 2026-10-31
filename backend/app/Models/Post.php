<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Post extends Model
{
    use HasFactory, HasUlids;

    protected $fillable = [
        'user_id',
        'shared_post_id',
        'body',
        'province_code',
        'city_code',
        'district_code',
        'village_code',
    ];

    /** Region columns the Publik feed can filter on, broadest first (copied from the author's address). */
    public const REGION_COLUMNS = ['province_code', 'city_code', 'district_code', 'village_code'];

    /** @return array<int, string|null> */
    public function regionCodes(): array
    {
        return array_values($this->only(self::REGION_COLUMNS));
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function sharedPost(): BelongsTo
    {
        return $this->belongsTo(Post::class, 'shared_post_id');
    }

    public function shares(): HasMany
    {
        return $this->hasMany(Post::class, 'shared_post_id');
    }

    public function media(): HasMany
    {
        return $this->hasMany(PostMedia::class)->orderBy('sort_order');
    }

    public function products(): BelongsToMany
    {
        return $this->belongsToMany(Product::class, 'post_products');
    }

    public function likes(): HasMany
    {
        return $this->hasMany(PostLike::class);
    }

    public function comments(): HasMany
    {
        return $this->hasMany(PostComment::class)->latest('created_at');
    }
}
