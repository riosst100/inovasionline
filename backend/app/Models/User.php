<?php

namespace App\Models;

use App\Notifications\ResetPasswordNotification;
use App\Support\Enums\UserRole;
use App\Support\Enums\UserVerificationStatus;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUlids, Notifiable, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'gender',
        'date_of_birth',
        'password',
        'google_id',
        'role',
        'avatar_path',
        'province_code',
        'city_code',
        'district_code',
        'village_code',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'date_of_birth' => 'date',
            'password' => 'hashed',
            'role' => UserRole::class,
        ];
    }

    public function sendPasswordResetNotification($token): void
    {
        $this->notify(new ResetPasswordNotification($token));
    }

    public function seller(): HasOne
    {
        return $this->hasOne(Seller::class);
    }

    public function sellerApplications(): HasMany
    {
        return $this->hasMany(SellerApplication::class);
    }

    public function userVerifications(): HasMany
    {
        return $this->hasMany(UserVerification::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function storeMemberships(): HasMany
    {
        return $this->hasMany(StoreMember::class);
    }

    public function photographer(): HasOne
    {
        return $this->hasOne(Photographer::class);
    }

    public function photographerApplications(): HasMany
    {
        return $this->hasMany(PhotographerApplication::class);
    }

    public function faceProfile(): HasOne
    {
        return $this->hasOne(UserFaceProfile::class);
    }

    public function matchedPhotos(): BelongsToMany
    {
        return $this->belongsToMany(Photo::class, 'photo_matches')
            ->using(PhotoMatch::class)
            ->withPivot(['confidence_score', 'matched_face_index'])
            ->withTimestamps();
    }

    public function photoPurchases(): HasMany
    {
        return $this->hasMany(PhotoPurchase::class);
    }

    public function isSeller(): bool
    {
        return in_array($this->role, [UserRole::SELLER_OWNER, UserRole::SELLER_STAFF], true);
    }

    public function isPlatformAdmin(): bool
    {
        return $this->role === UserRole::PLATFORM_ADMIN;
    }

    public function isVerified(): bool
    {
        return $this->userVerifications()->where('status', UserVerificationStatus::APPROVED)->exists();
    }

    public function hasAddress(): bool
    {
        return $this->province_code !== null
            && $this->city_code !== null
            && $this->district_code !== null
            && $this->village_code !== null;
    }

    public function chatThreadParticipations(): HasMany
    {
        return $this->hasMany(ChatThreadParticipant::class);
    }

    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }
}
