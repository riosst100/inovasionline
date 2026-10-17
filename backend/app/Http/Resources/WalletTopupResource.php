<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTopupResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'topup_number' => $this->topup_number,
            'amount' => (float) $this->amount,
            'status' => $this->status,
            'payment_redirect_url' => $this->status === 'pending' ? $this->payment_redirect_url : null,
            'payment_expires_at' => $this->payment_expires_at,
            'midtrans_payment_type' => $this->midtrans_payment_type,
            'paid_at' => $this->paid_at,
            'created_at' => $this->created_at,
        ];
    }
}
