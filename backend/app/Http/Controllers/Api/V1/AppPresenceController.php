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
     */
    public function heartbeat(Request $request): JsonResponse
    {
        $data = $request->validate([
            'install_id' => ['required', 'string', 'min:16', 'max:64'],
            'platform' => ['required', 'string', 'in:android,ios,web,other'],
            'app_version' => ['nullable', 'string', 'max:32'],
            'build_number' => ['nullable', 'integer', 'min:0'],
            'screen' => ['nullable', 'string', 'max:120'],
        ]);

        $now = now();
        $install = AppInstall::query()->firstOrNew(['install_id' => $data['install_id']]);
        $install->fill([
            'platform' => $data['platform'],
            'app_version' => $data['app_version'] ?? $install->app_version,
            'build_number' => $data['build_number'] ?? $install->build_number,
            'current_screen' => $data['screen'] ?? $install->current_screen,
            'last_seen_at' => $now,
        ]);
        $install->first_seen_at ??= $now;
        if (($user = auth('sanctum')->user()) instanceof User) {
            $install->user_id = $user->getKey();
        }
        $install->save();

        return ApiResponse::success(null, 'OK');
    }
}
