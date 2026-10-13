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

    protected $fillable = [
        'name',
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
        ];
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
