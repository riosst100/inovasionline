<?php

namespace App\Http\Controllers\Api\Admin;

use App\Events\OrderTrackingUpdated;
use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\Order;
use App\Support\Enums\OrderStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The driver app reports its GPS position while it has parcels on the way. Only the latest fix is
 * kept (on the courier's account); buyers of the parcels being carried get a signal to refetch.
 */
class DriverLocationController extends Controller
{
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy' => ['nullable', 'numeric', 'min:0'],
        ]);

        $driver = $request->user();

        // A query update, so the frequent pings don't fire model events (dashboard signals etc.).
        AdminUser::whereKey($driver->id)->update([
            'last_latitude' => $data['latitude'],
            'last_longitude' => $data['longitude'],
            'last_location_accuracy' => $data['accuracy'] ?? null,
            'last_location_at' => now(),
        ]);

        Order::query()
            ->where('driver_id', $driver->id)
            ->where('status', OrderStatus::ON_DELIVERY)
            ->pluck('id')
            ->each(fn (string $orderId) => OrderTrackingUpdated::dispatch($orderId));

        return ApiResponse::success(null, 'Lokasi diperbarui.');
    }
}
