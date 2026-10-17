<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NavBadgeSetting extends Model
{
    protected $fillable = ['is_active', 'label', 'starts_at', 'ends_at'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public static function current(): self
    {
        return static::query()->first() ?? new static([
            'is_active' => false,
            'label' => '12.12 Sale',
        ]);
    }

    /** Active and inside its optional schedule window. */
    public function isVisible(): bool
    {
        return $this->is_active
            && trim((string) $this->label) !== ''
            && ($this->starts_at === null || $this->starts_at->isPast())
            && ($this->ends_at === null || $this->ends_at->isFuture());
    }

    public function toPayload(): array
    {
        return [
            'is_active' => (bool) $this->is_active,
            'label' => $this->label,
            'starts_at' => $this->starts_at?->toIso8601String(),
            'ends_at' => $this->ends_at?->toIso8601String(),
            'is_visible' => $this->isVisible(),
        ];
    }
}
