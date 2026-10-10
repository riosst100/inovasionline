<?php

namespace App\Http\Resources;

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
            'avatar_url' => $this->avatar_path ? asset('storage/'.$this->avatar_path) : null,
            'is_seller' => $this->isSeller(),
            'is_verified' => $this->isVerified(),
            'has_address' => $this->hasAddress(),
            'province_code' => $this->province_code,
            'city_code' => $this->city_code,
            'district_code' => $this->district_code,
            'village_code' => $this->village_code,
            'email_verified_at' => $this->email_verified_at,
            'created_at' => $this->created_at,
        ];
    }
}
