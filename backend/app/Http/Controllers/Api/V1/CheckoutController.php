<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\CheckoutService;
use App\Services\CodVerificationRequiredException;
use App\Services\PaylaterNotEligibleException;
use App\Services\PaylaterVerificationRequiredException;
use App\Support\DeviceInfo;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use RuntimeException;
use Throwable;

class CheckoutController extends Controller
{
    public function __construct(private readonly CheckoutService $checkoutService) {}

    public function store(CheckoutRequest $request): JsonResponse
    {
        try {
            $order = $this->checkoutService->checkout($request->user(), $request->validated());
        } catch (CodVerificationRequiredException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage(), 'code' => CodVerificationRequiredException::CODE], 422);
        } catch (PaylaterVerificationRequiredException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage(), 'code' => PaylaterVerificationRequiredException::CODE], 422);
        } catch (PaylaterNotEligibleException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage(), 'code' => PaylaterNotEligibleException::CODE], 422);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        if ($addressId = $request->validated('address_id')) {
            $request->user()->addresses()->whereKey($addressId)->update(['last_used_at' => now()]);
        }

        $this->logDevice($order, $request);

        return ApiResponse::success(new OrderResource($order), 'Order placed successfully.', [], 201);
    }

    /** Freezes where the order was placed from; never fails the checkout. */
    private function logDevice(Order $order, CheckoutRequest $request): void
    {
        $data = $request->validated();
        $location = $data['location'] ?? null;

        try {
            $order->deviceLog()->create([
                ...DeviceInfo::columns($data['device'] ?? []),
                'user_id' => $request->user()->getKey(),
                'install_id' => $data['install_id'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'build_number' => $data['build_number'] ?? null,
                'ip_address' => $request->ip(),
                'user_agent' => mb_substr((string) $request->userAgent(), 0, 500),
                'latitude' => $location['latitude'] ?? null,
                'longitude' => $location['longitude'] ?? null,
                'location_accuracy' => $location['accuracy'] ?? null,
                'location_at' => $location['at'] ?? null,
            ]);
        } catch (Throwable $e) {
            report($e);
        }
    }
}
