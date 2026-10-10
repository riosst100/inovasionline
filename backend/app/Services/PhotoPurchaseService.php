<?php

namespace App\Services;

use App\Models\Photo;
use App\Models\PhotoPurchase;
use App\Models\User;
use App\Support\Enums\PhotoPurchaseStatus;
use RuntimeException;

class PhotoPurchaseService
{
    public function purchase(User $user, Photo $photo, int $matchedFaceIndex = 0): PhotoPurchase
    {
        $existing = PhotoPurchase::where('user_id', $user->id)
            ->where('photo_id', $photo->id)
            ->where('matched_face_index', $matchedFaceIndex)
            ->first();

        if ($existing) {
            throw new RuntimeException('You have already purchased this photo.');
        }

        // Instant unlock for v1 — no payment gateway exists yet elsewhere in
        // the app, so the purchase is recorded as paid immediately.
        return PhotoPurchase::create([
            'user_id' => $user->id,
            'photo_id' => $photo->id,
            'matched_face_index' => $matchedFaceIndex,
            'price' => $photo->price,
            'status' => PhotoPurchaseStatus::PAID,
            'purchased_at' => now(),
        ]);
    }
}
