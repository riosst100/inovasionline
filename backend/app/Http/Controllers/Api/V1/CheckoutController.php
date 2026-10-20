<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\OrderResource;
use App\Services\CheckoutService;
use App\Services\CodVerificationRequiredException;
use App\Services\PaylaterNotEligibleException;
use App\Services\PaylaterVerificationRequiredException;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use RuntimeException;

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

        return ApiResponse::success(new OrderResource($order), 'Order placed successfully.', [], 201);
    }
}
