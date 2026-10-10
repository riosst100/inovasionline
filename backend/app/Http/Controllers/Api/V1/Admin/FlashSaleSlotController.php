<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\FlashSaleSlotRequest;
use App\Http\Resources\FlashSaleSlotResource;
use App\Models\FlashSaleSlot;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class FlashSaleSlotController extends Controller
{
    public function index(): JsonResponse
    {
        $slots = FlashSaleSlot::query()->orderBy('sort_order')->orderBy('start_time')->get();

        return ApiResponse::success(FlashSaleSlotResource::collection($slots), 'Flash sale slots retrieved successfully.');
    }

    public function store(FlashSaleSlotRequest $request): JsonResponse
    {
        $slot = FlashSaleSlot::create([
            ...$request->validated(),
            'is_active' => $request->boolean('is_active', true),
        ]);

        return ApiResponse::success(new FlashSaleSlotResource($slot), 'Flash sale slot created successfully.', [], 201);
    }

    public function update(FlashSaleSlotRequest $request, FlashSaleSlot $flashSaleSlot): JsonResponse
    {
        $flashSaleSlot->update($request->validated());

        return ApiResponse::success(new FlashSaleSlotResource($flashSaleSlot), 'Flash sale slot updated successfully.');
    }

    public function destroy(FlashSaleSlot $flashSaleSlot): JsonResponse
    {
        $flashSaleSlot->delete();

        return ApiResponse::success(null, 'Flash sale slot deleted successfully.');
    }
}
