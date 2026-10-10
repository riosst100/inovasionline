<?php

namespace App\Http\Resources;

use App\Models\PhotoPurchase;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Auth;

class PhotoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $userId = Auth::id();

        $isPurchased = $userId && PhotoPurchase::where('user_id', $userId)
            ->where('photo_id', $this->id)
            ->where('status', 'paid')
            ->exists();

        $matchedPivot = $this->whenPivotLoaded('photo_matches', fn () => $this->pivot);

        return [
            'id' => $this->id,
            'photographer_name' => $this->whenLoaded('photographer', fn () => $this->photographer->display_name),
            'event_title' => $this->whenLoaded('event', fn () => $this->event?->title),
            'price' => (float) $this->price,
            'status' => $this->status?->value,
            'face_count' => $this->face_count,
            'is_purchased' => $isPurchased,
            'is_matched' => $matchedPivot !== null,
            'confidence_score' => $matchedPivot ? (float) $matchedPivot->confidence_score : null,
            'url' => $isPurchased ? asset('storage/'.$this->path) : null,
            'watermarked_url' => $this->watermarked_path ? asset('storage/'.$this->watermarked_path) : null,
            'taken_at' => $this->taken_at,
            'created_at' => $this->created_at,
        ];
    }
}
