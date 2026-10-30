<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class AdminUser extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUlids, Notifiable, SoftDeletes;

    protected $table = 'admin_users';

    public const USERNAME_MAX = 50;

    /** Lowercase letters, digits, dot and underscore; used to log in. */
    public const USERNAME_RULE = 'regex:/^[a-z0-9._]{3,50}$/';

    protected $fillable = [
        'name',
        'username',
        'email',
        'phone',
        'vehicle_type',
        'vehicle_plate_number',
        'password',
        'role_id',
        'avatar_path',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'is_active' => 'boolean',
            'last_latitude' => 'float',
            'last_longitude' => 'float',
            'last_location_accuracy' => 'float',
            'last_location_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        // Accounts created without one (drivers, seeders) get a username from their email.
        static::creating(function (AdminUser $user) {
            $user->username = $user->username
                ? self::normalizeUsername($user->username)
                : self::uniqueUsername($user->email ?: $user->name);
        });
    }

    public static function normalizeUsername(string $username): string
    {
        return mb_strtolower(trim($username));
    }

    /**
     * One stored form for an Indonesian phone number, so a courier signing in with "+62 812-…" or "0812…" finds
     * the same account: digits only, starting with 0 (62… and 8… are rewritten). Null when there are no digits.
     */
    public static function normalizePhone(?string $phone): ?string
    {
        $digits = preg_replace('/\D/', '', (string) $phone);
        if ($digits === '') {
            return null;
        }
        if (str_starts_with($digits, '62')) {
            return '0'.substr($digits, 2);
        }

        return str_starts_with($digits, '8') ? '0'.$digits : $digits;
    }

    /** Free username derived from an email (its local part) or a name. */
    public static function uniqueUsername(string $source): string
    {
        $base = preg_replace('/[^a-z0-9._]/', '', self::normalizeUsername(explode('@', $source)[0]));
        $base = substr(str_pad($base, 3, '0'), 0, self::USERNAME_MAX - 4);

        $username = $base;
        for ($i = 2; static::withTrashed()->where('username', $username)->exists(); $i++) {
            $username = $base.$i;
        }

        return $username;
    }

    public function deliveredOrders(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Order::class, 'driver_id');
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function isSuperAdmin(): bool
    {
        return optional($this->role)->slug === 'super_admin';
    }

    public function hasPermission(string $permission): bool
    {
        if ($this->isSuperAdmin()) {
            return true;
        }

        $perms = $this->role?->permissions ?? [];
        return in_array('*', $perms, true) || in_array($permission, $perms, true);
    }
}
