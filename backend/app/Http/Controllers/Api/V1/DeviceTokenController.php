<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreDeviceTokenRequest;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(StoreDeviceTokenRequest $request): JsonResponse
    {
        $request->user()->deviceTokens()->updateOrCreate(
            ['token' => $request->validated('token')],
            ['platform' => $request->validated('platform')]
        );

        return ApiResponse::success(null, 'Device token registered successfully.');
    }

    public function destroy(Request $request): JsonResponse
    {
        $request->validate(['token' => ['required', 'string']]);

        $request->user()->deviceTokens()->where('token', $request->string('token'))->delete();

        return ApiResponse::success(null, 'Device token removed successfully.');
    }
}
