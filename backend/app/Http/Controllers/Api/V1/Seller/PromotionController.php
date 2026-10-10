<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\PromotionRequest;
use App\Http\Resources\PromotionResource;
use App\Models\Store;
use App\Services\PromotionService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class PromotionController extends Controller
{
    public function __construct(private readonly PromotionService $promotionService) {}

    public function index(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $promotions = $store->promotions()
            ->with('products.images', 'flashSaleSlot')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($promotions, PromotionResource::class, 'Promotions retrieved successfully.');
    }

    public function store(PromotionRequest $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        try {
            $promotion = $this->promotionService->create($store, $request->validated());
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new PromotionResource($promotion), 'Promotion created successfully.', [], 201);
    }
}
