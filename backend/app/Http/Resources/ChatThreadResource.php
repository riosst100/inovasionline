<?php

namespace App\Http\Resources;

use App\Support\Enums\ChatRegionLevel;
use App\Support\Enums\ChatThreadType;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Laravolt\Indonesia\Models\City;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Province;
use Laravolt\Indonesia\Models\Village;

class ChatThreadResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $viewer = $request->user();
        $otherUser = null;

        if ($this->type === ChatThreadType::DM && $viewer) {
            $otherUser = $this->user_one_id === $viewer->id ? $this->userTwo : $this->userOne;
        }

        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'region_level' => $this->region_level?->value,
            'region_code' => $this->region_code,
            'title' => $this->resolveTitle($otherUser),
            'other_user' => $otherUser ? [
                'id' => $otherUser->id,
                'name' => $otherUser->name,
                'avatar_url' => $otherUser->avatar_path ? asset('storage/'.$otherUser->avatar_path) : null,
                'is_seller' => $otherUser->isSeller(),
            ] : null,
            'latest_message' => $this->whenLoaded('latestMessage', fn () => $this->latestMessage ? [
                'body' => $this->latestMessage->body,
                'sender_id' => $this->latestMessage->sender_id,
                'sender_name' => $this->latestMessage->sender?->name,
                'created_at' => $this->latestMessage->created_at,
            ] : null),
            'participant_count' => $this->when($this->type !== ChatThreadType::DM, fn () => $this->participants_count),
            'is_favorite' => $this->whenLoaded('viewerParticipant', fn () => $this->viewerParticipant?->is_favorite ?? false),
            'is_unread' => $this->whenLoaded('viewerParticipant', fn () => $this->resolveIsUnread($viewer)),
            'updated_at' => $this->updated_at,
        ];
    }

    private function resolveIsUnread(?object $viewer): bool
    {
        $latestMessage = $this->latestMessage;
        if ($latestMessage === null) {
            return false;
        }

        if ($viewer && $latestMessage->sender_id === $viewer->id) {
            return false;
        }

        $lastReadAt = $this->viewerParticipant?->last_read_at;

        return $lastReadAt === null || $lastReadAt->lt($latestMessage->created_at);
    }

    private function resolveTitle(?object $otherUser): string
    {
        return match ($this->type) {
            ChatThreadType::GLOBAL => 'Warga +62',
            ChatThreadType::OFFICIAL => 'Inovasi Online',
            ChatThreadType::REGION => $this->resolveRegionName(),
            ChatThreadType::DM => $otherUser?->name ?? 'Percakapan',
        };
    }

    private function resolveRegionName(): string
    {
        $model = match ($this->region_level) {
            ChatRegionLevel::PROVINCE => Province::where('code', $this->region_code)->first(),
            ChatRegionLevel::CITY => City::where('code', $this->region_code)->first(),
            ChatRegionLevel::DISTRICT => District::where('code', $this->region_code)->first(),
            ChatRegionLevel::VILLAGE => Village::where('code', $this->region_code)->first(),
            default => null,
        };

        $name = str($model?->name ?? 'Wilayah')->title()->toString();

        // City names already include their own prefix (e.g. "Kabupaten
        // Brebes", "Kota Jakarta Pusat"), so no extra prefix is added.
        $prefix = match ($this->region_level) {
            ChatRegionLevel::PROVINCE => 'Provinsi',
            ChatRegionLevel::DISTRICT => 'Kecamatan',
            ChatRegionLevel::VILLAGE => 'Desa',
            default => '',
        };

        return trim("{$prefix} {$name}");
    }
}
