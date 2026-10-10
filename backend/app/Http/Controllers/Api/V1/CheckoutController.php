<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\OrderResource;
use App\Services\CheckoutService;
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
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new OrderResource($order), 'Order placed successfully.', [], 201);
    }
}
