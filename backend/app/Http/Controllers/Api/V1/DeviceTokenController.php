<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreDeviceTokenRequest;
use App\Models\DeviceToken;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * Public route. Anonymous devices are stored without a user; a signed-in caller links the token
     * to their account. An anonymous call never clears an existing link, so an app that registers
     * at startup (before its session is restored) does not detach the user.
     */
    public function store(StoreDeviceTokenRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');

        $attributes = [
            'platform' => $request->validated('platform'),
            'last_seen_at' => now(),
        ];
        if ($user) {
            $attributes['user_id'] = $user->id;
        }

        DeviceToken::updateOrCreate(['token' => $request->validated('token')], $attributes);

        return ApiResponse::success(null, 'Device token registered successfully.');
    }

    /**
     * Logout: the token stays (so broadcasts still reach the device) but is no longer tied to the user.
     */
    public function destroy(Request $request): JsonResponse
    {
        $request->validate(['token' => ['required', 'string']]);

        $request->user()->deviceTokens()->where('token', $request->string('token'))->update(['user_id' => null]);

        return ApiResponse::success(null, 'Device token removed successfully.');
    }
}
