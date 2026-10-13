<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AdminUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'vehicle_type' => $this->vehicle_type,
            'vehicle_plate_number' => $this->vehicle_plate_number,
            'delivered_orders_count' => $this->whenCounted('deliveredOrders', $this->delivered_orders_count, $this->deliveredOrders()->count()),
            'avatar_url' => $this->avatar_path ? asset('storage/'.$this->avatar_path) : null,
            'is_active' => $this->is_active,
            'role_id' => $this->role_id,
            'is_super_admin' => $this->isSuperAdmin(),
            'role' => $this->role ? [
                'id' => $this->role->id,
                'name' => $this->role->name,
                'slug' => $this->role->slug,
                'description' => $this->role->description,
                'permissions' => $this->role->permissions ?? [],
            ] : null,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
