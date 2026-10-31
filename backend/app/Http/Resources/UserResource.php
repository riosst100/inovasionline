<?php

namespace App\Http\Resources;

use App\Services\RegionLocator;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'gender' => $this->gender,
            'date_of_birth' => $this->date_of_birth?->toDateString(),
            'role' => $this->role?->value,
            'role_id' => $this->role_id,
            'is_super_admin' => $this->isSuperAdmin(),
            'assigned_role' => $this->assignedRole ? [
                'id' => $this->assignedRole->id,
                'name' => $this->assignedRole->name,
                'slug' => $this->assignedRole->slug,
                'description' => $this->assignedRole->description,
                'permissions' => $this->assignedRole->permissions ?? [],
            ] : null,
            'avatar_url' => $this->avatar_path ? asset('storage/'.$this->avatar_path) : null,
            'is_blocked' => $this->isBlocked(),
            'blocked_at' => $this->blocked_at,
            'block_reason' => $this->block_reason,
            'contact_url' => $this->isBlocked() ? config('services.support.contact_url') : null,
            'banned_features' => $this->banned_features ?? [],
            'ban_reason' => $this->ban_reason,
            'is_verified' => $this->isVerified(),
            // Admin-granted verified badge; the user's posts show in the app's "Resmi" tab.
            'has_verified_badge' => $this->hasVerifiedBadge(),
            'verified_badge_at' => $this->verified_badge_at,
            // Regions this user looks after ("Admin <region>" badge).
            'region_admins' => $this->regionAdmins->map(fn ($a) => [
                'id' => $a->id,
                'region_level' => $a->region_level->value,
                'region_code' => $a->region_code,
                'region_name' => $a->region_name,
                'badge_text' => $a->badge_text,
                'label' => $a->label(),
                'community_role_id' => $a->community_role_id,
                'role_name' => $a->role?->name,
            ])->values(),
            // Face verification (COD/Paylater): null = never, verified, or revoked; verification_id is the event behind it.
            'verification_status' => $this->verification_status,
            'verification_id' => $this->verification_id,
            'last_seen_at' => $this->when(
                array_key_exists('last_seen_at', $this->resource->getAttributes()),
                fn () => $this->last_seen_at
            ),
            'has_address' => $this->hasAddress(),
            'address_label' => $this->hasAddress() ? app(RegionLocator::class)->labelForVillage($this->village_code) : null,
            'province_code' => $this->province_code,
            'city_code' => $this->city_code,
            'district_code' => $this->district_code,
            'village_code' => $this->village_code,
            'email_verified_at' => $this->email_verified_at,
            'created_at' => $this->created_at,
        ];
    }
}
