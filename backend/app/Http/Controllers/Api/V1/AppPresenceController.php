<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppInstall;
use App\Models\User;
use App\Support\DeviceInfo;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppPresenceController extends Controller
{
    /**
     * Sent by the customer app on launch, on every screen change and
     * periodically while in the foreground. Public so installs are counted
     * before login; the bearer token, when present, links the user.
     *
     * The first heartbeat after launch also carries `device` (for security);
     * the device fields are self-reported, so treat them as hints. The IP is
     * read from the request on every heartbeat.
     */
    public function heartbeat(Request $request): JsonResponse
    {
        $data = $request->validate([
            'install_id' => ['required', 'string', 'min:16', 'max:64'],
            'platform' => ['required', 'string', 'in:android,ios,web,other'],
            'app_version' => ['nullable', 'string', 'max:32'],
            'build_number' => ['nullable', 'integer', 'min:0'],
            'screen' => ['nullable', 'string', 'max:120'],
            'location' => ['nullable', 'array'],
            'location.latitude' => ['required_with:location', 'numeric', 'between:-90,90'],
            'location.longitude' => ['required_with:location', 'numeric', 'between:-180,180'],
            'location.accuracy' => ['nullable', 'numeric', 'min:0'],
            'location.at' => ['nullable', 'date'],
            ...DeviceInfo::rules(),
        ]);

        $now = now();
        $ip = $request->ip();
        $install = AppInstall::query()->firstOrNew(['install_id' => $data['install_id']]);
        $install->fill([
            'platform' => $data['platform'],
            'app_version' => $data['app_version'] ?? $install->app_version,
            'build_number' => $data['build_number'] ?? $install->build_number,
            'current_screen' => $data['screen'] ?? $install->current_screen,
            'ip_address' => $ip,
            'user_agent' => mb_substr((string) $request->userAgent(), 0, 500),
            'last_seen_at' => $now,
        ]);
        if ($location = $data['location'] ?? null) {
            $install->fill([
                'latitude' => $location['latitude'],
                'longitude' => $location['longitude'],
                'location_accuracy' => $location['accuracy'] ?? null,
                'location_at' => $location['at'] ?? $now,
            ]);
        }
        if ($device = $data['device'] ?? null) {
            $install->fill(array_filter(DeviceInfo::columns($device), fn ($value) => $value !== null));
        }
        $install->first_seen_at ??= $now;
        $install->first_ip_address ??= $ip;
        if (($user = auth('sanctum')->user()) instanceof User) {
            $install->user_id = $user->getKey();
        }
        $install->save();

        return ApiResponse::success(null, 'OK');
    }
}
