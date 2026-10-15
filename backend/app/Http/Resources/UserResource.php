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
            'is_seller' => $this->isSeller(),
            'is_verified' => $this->isVerified(),
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
