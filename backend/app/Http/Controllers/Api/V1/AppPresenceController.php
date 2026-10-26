<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppInstall;
use App\Models\User;
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
            'device' => ['nullable', 'array'],
            'device.id' => ['nullable', 'string', 'max:128'],
            'device.name' => ['nullable', 'string', 'max:120'],
            'device.brand' => ['nullable', 'string', 'max:60'],
            'device.model' => ['nullable', 'string', 'max:120'],
            'device.os_version' => ['nullable', 'string', 'max:60'],
            'device.is_emulator' => ['nullable', 'boolean'],
            'device.details' => ['nullable', 'array', 'max:30'],
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
            'last_seen_at' => $now,
        ]);
        if ($device = $data['device'] ?? null) {
            $install->fill([
                'device_id' => $device['id'] ?? $install->device_id,
                'device_name' => $device['name'] ?? $install->device_name,
                'device_brand' => $device['brand'] ?? $install->device_brand,
                'device_model' => $device['model'] ?? $install->device_model,
                'os_version' => $device['os_version'] ?? $install->os_version,
                'is_emulator' => $device['is_emulator'] ?? $install->is_emulator,
                'device_details' => $device['details'] ?? $install->device_details,
            ]);
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
