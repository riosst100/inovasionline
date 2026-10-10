<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\FlashSaleScheduleSlotResource;
use App\Http\Resources\PublicProductDetailResource;
use App\Http\Resources\PublicProductResource;
use App\Models\FlashSaleSlot;
use App\Models\Product;
use App\Models\Promotion;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\PromotionType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class PublicProductController extends Controller
{
    public function flashSale(Request $request): JsonResponse
    {
        $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);

        $requestedDate = $request->string('date')->toString() ?: null;
        $date = $requestedDate ?: $this->resolveNearestFlashSaleDate();

        if (! $date) {
            return ApiResponse::success(['date' => null, 'slots' => [], 'available_dates' => []], 'Flash sale products retrieved successfully.');
        }

        $slots = FlashSaleSlot::query()
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('start_time')
            ->get();

        $now = now();

        $schedule = $slots->map(function (FlashSaleSlot $slot) use ($date, $now) {
            $startsAt = Carbon::parse("{$date} {$slot->start_time}");
            $endsAt = Carbon::parse("{$date} {$slot->end_time}");

            $products = Product::query()
                ->where('status', ProductStatus::ACTIVE)
                ->whereHas('promotions', function ($query) use ($slot, $date) {
                    $query->where('flash_sale_slot_id', $slot->id)
                        ->where('is_active', true)
                        ->whereDate('starts_at', $date)
                        ->whereIn('type', [PromotionType::PERCENTAGE_DISCOUNT, PromotionType::FIXED_DISCOUNT]);
                })
                ->with([
                    'images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0),
                    'store',
                    'promotions' => function ($query) use ($slot, $date) {
                        $query->where('flash_sale_slot_id', $slot->id)
                            ->where('is_active', true)
                            ->whereDate('starts_at', $date)
                            ->whereIn('type', [PromotionType::PERCENTAGE_DISCOUNT, PromotionType::FIXED_DISCOUNT])
                            ->orderBy('discount_value', 'desc');
                    },
                ])
                ->get();

            $status = match (true) {
                $now->between($startsAt, $endsAt) => 'active',
                $now->lt($startsAt) => 'upcoming',
                default => 'ended',
            };

            return [
                'slot' => $slot,
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'status' => $status,
                'products' => $products,
            ];
        });

        return ApiResponse::success([
            'date' => $date,
            'slots' => FlashSaleScheduleSlotResource::collection($schedule),
            'available_dates' => $this->availableFlashSaleDates(),
        ], 'Flash sale products retrieved successfully.');
    }

    public function show(Product $product): JsonResponse
    {
        if ($product->status !== ProductStatus::ACTIVE) {
            throw new NotFoundHttpException;
        }

        $product->load([
            'images',
            'category',
            'store.seller',
            'variants',
            'promotions' => function ($query) {
                $query->where('is_active', true)
                    ->where('starts_at', '<=', now())
                    ->where('ends_at', '>=', now())
                    ->whereIn('type', [PromotionType::PERCENTAGE_DISCOUNT, PromotionType::FIXED_DISCOUNT])
                    ->orderBy('discount_value', 'desc');
            },
        ]);

        $product->loadSum(['orderItems as order_items_sum_quantity' => function ($query) {
            $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
        }], 'quantity');

        return ApiResponse::success(new PublicProductDetailResource($product), 'Product retrieved successfully.');
    }

    public function bestSellers(Request $request): JsonResponse
    {
        $products = Product::query()
            ->where('status', ProductStatus::ACTIVE)
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0), 'store'])
            ->withSum(['orderItems as order_items_sum_quantity' => function ($query) {
                $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
            }], 'quantity')
            ->orderByDesc('order_items_sum_quantity')
            ->limit($request->integer('limit', 12))
            ->get();

        return ApiResponse::success(PublicProductResource::collection($products), 'Best seller products retrieved successfully.');
    }

    private function resolveNearestFlashSaleDate(): ?string
    {
        $today = now()->toDateString();

        $hasToday = Promotion::query()
            ->whereNotNull('flash_sale_slot_id')
            ->where('is_active', true)
            ->whereDate('starts_at', $today)
            ->exists();

        if ($hasToday) {
            return $today;
        }

        $upcoming = Promotion::query()
            ->whereNotNull('flash_sale_slot_id')
            ->where('is_active', true)
            ->whereDate('starts_at', '>', $today)
            ->orderBy('starts_at')
            ->first();

        return $upcoming?->starts_at->toDateString();
    }

    /**
     * @return list<string>
     */
    private function availableFlashSaleDates(): array
    {
        $today = now()->toDateString();

        return Promotion::query()
            ->whereNotNull('flash_sale_slot_id')
            ->where('is_active', true)
            ->whereDate('ends_at', '>=', $today)
            ->orderBy('starts_at')
            ->get(['starts_at'])
            ->map(fn (Promotion $promotion) => $promotion->starts_at->toDateString())
            ->unique()
            ->values()
            ->all();
    }
}
