<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PhotoEventResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'slug' => $this->slug,
            'event_date' => $this->event_date,
            'cover_photo_url' => $this->cover_photo_path ? asset('storage/'.$this->cover_photo_path) : null,
            'status' => $this->status,
            'created_at' => $this->created_at,
        ];
    }
}
