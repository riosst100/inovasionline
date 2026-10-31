<?php

namespace App\Models;

use App\Support\Enums\ChatRegionLevel;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A user appointed by an admin to one region with a community role (what they may do there) and a badge
 * worded freely, e.g. "Kepala Desa <wilayah>".
 */
class RegionAdmin extends Model
{
    use HasUlids;

    /** Levels that have a region chat (see ChatService::syncMembershipsForUser). */
    public const LEVELS = [ChatRegionLevel::CITY, ChatRegionLevel::DISTRICT, ChatRegionLevel::VILLAGE];

    /** Stands for the region name in badge_text. */
    public const REGION_PLACEHOLDER = '<wilayah>';

    public const DEFAULT_BADGE_TEXT = 'Admin '.self::REGION_PLACEHOLDER;

    protected $fillable = [
        'user_id',
        'community_role_id',
        'region_level',
        'region_code',
        'region_name',
        'badge_text',
    ];

    protected function casts(): array
    {
        return [
            'region_level' => ChatRegionLevel::class,
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(CommunityRole::class, 'community_role_id');
    }

    /** The badge as shown, e.g. "Kepala Desa Tiwulandu" from "Kepala Desa <wilayah>". */
    public function label(): string
    {
        return str_replace(self::REGION_PLACEHOLDER, $this->region_name, $this->badge_text ?? self::DEFAULT_BADGE_TEXT);
    }

    public function can(string $ability): bool
    {
        return (bool) $this->role?->can($ability);
    }
}
