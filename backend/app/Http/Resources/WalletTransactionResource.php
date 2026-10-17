<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'amount' => (float) $this->amount,
            'balance_after' => (float) $this->balance_after,
            'description' => $this->description,
            'order_id' => $this->order_id,
            'admin' => $this->whenLoaded('adminUser', fn () => $this->adminUser ? ['id' => $this->adminUser->id, 'name' => $this->adminUser->name] : null),
            'created_at' => $this->created_at,
        ];
    }
}
