<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\FlashSaleSlotResource;
use App\Models\FlashSaleSlot;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class FlashSaleSlotController extends Controller
{
    public function index(): JsonResponse
    {
        $slots = FlashSaleSlot::query()
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('start_time')
            ->get();

        return ApiResponse::success(FlashSaleSlotResource::collection($slots), 'Flash sale slots retrieved successfully.');
    }
}
