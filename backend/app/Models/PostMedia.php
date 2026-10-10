<?php

namespace App\Models;

use App\Support\Enums\PostMediaType;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PostMedia extends Model
{
    use HasUlids;

    protected $fillable = [
        'post_id',
        'type',
        'path',
        'thumbnail_path',
        'duration_seconds',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'type' => PostMediaType::class,
        ];
    }

    public function post(): BelongsTo
    {
        return $this->belongsTo(Post::class);
    }
}
