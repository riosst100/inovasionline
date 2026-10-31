<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Role of a region appointment (Admin, Moderator, ...); admins pick its abilities in the dashboard. */
class CommunityRole extends Model
{
    use HasUlids;

    public const DELETE_POSTS = 'delete_posts';

    public const DELETE_COMMENTS = 'delete_comments';

    public const DELETE_CHAT_MESSAGES = 'delete_chat_messages';

    /** Every ability with its dashboard label. */
    public const ABILITIES = [
        self::DELETE_POSTS => 'Hapus postingan',
        self::DELETE_COMMENTS => 'Hapus komentar',
        self::DELETE_CHAT_MESSAGES => 'Hapus chat',
    ];

    protected $fillable = [
        'name',
        'abilities',
    ];

    protected function casts(): array
    {
        return [
            'abilities' => 'array',
        ];
    }

    public function appointments(): HasMany
    {
        return $this->hasMany(RegionAdmin::class);
    }

    public function can(string $ability): bool
    {
        return in_array($ability, $this->abilities ?? [], true);
    }
}
