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
    private const TIMEZONE = 'Asia/Jakarta';

    /**
     * Flash sales for one local (WIB) date. Each flash sale is returned as a "slot"
     * with its own window, so the response shape stays what the app expects.
     */
    public function flashSale(Request $request): JsonResponse
    {
        $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);

        $requestedDate = $request->string('date')->toString() ?: null;
        $date = $requestedDate ?: $this->resolveNearestFlashSaleDate();

        if (! $date) {
            return ApiResponse::success(['date' => null, 'slots' => [], 'available_dates' => []], 'Flash sale products retrieved successfully.');
        }

        $dayStart = Carbon::parse($date, self::TIMEZONE)->startOfDay()->utc();
        $dayEnd = Carbon::parse($date, self::TIMEZONE)->endOfDay()->utc();

        $flashSales = $this->flashSaleQuery()
            ->where('starts_at', '<=', $dayEnd)
            ->where('ends_at', '>=', $dayStart)
            ->orderBy('starts_at')
            ->get();

        $now = now();

        $schedule = $flashSales->map(function (Promotion $flashSale) use ($now) {
            $products = Product::query()
                ->where('status', ProductStatus::ACTIVE)
                ->whereHas('promotions', fn ($query) => $query->whereKey($flashSale->id))
                ->withStock()
                ->with([
                    'images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0),
                    'promotions' => fn ($query) => $query->whereKey($flashSale->id),
                ])
                ->get();

            $status = match (true) {
                $now->between($flashSale->starts_at, $flashSale->ends_at) => 'active',
                $now->lt($flashSale->starts_at) => 'upcoming',
                default => 'ended',
            };

            return [
                'slot' => (object) [
                    'id' => $flashSale->id,
                    'label' => $flashSale->name,
                    'start_time' => $flashSale->starts_at->copy()->setTimezone(self::TIMEZONE)->format('H:i'),
                    'end_time' => $flashSale->ends_at->copy()->setTimezone(self::TIMEZONE)->format('H:i'),
                ],
                'starts_at' => $flashSale->starts_at,
                'ends_at' => $flashSale->ends_at,
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

        // Feeds "most viewed" on the admin dashboard; bypasses Eloquent so
        // updated_at is left alone.
        $product->newQuery()->toBase()->where('id', $product->id)->increment('view_count');

        $product->load([
            'images',
            'category',
            'variants',
            'promotions' => function ($query) {
                $query->where('is_active', true)
                    ->where('starts_at', '<=', now())
                    ->where('ends_at', '>=', now())
                    ->whereIn('type', [PromotionType::PERCENTAGE_DISCOUNT, PromotionType::FIXED_DISCOUNT, PromotionType::FLASH_SALE]);
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
            ->withStock()
            ->with(['images' => fn ($query) => $query->where('is_primary', true)->orWhere('sort_order', 0)])
            ->withSum(['orderItems as order_items_sum_quantity' => function ($query) {
                $query->whereHas('order', fn ($q) => $q->where('status', OrderStatus::COMPLETED));
            }], 'quantity')
            ->orderByDesc('order_items_sum_quantity')
            ->orderByDesc('view_count')
            ->limit($request->integer('limit', 12))
            ->get();

        return ApiResponse::success(PublicProductResource::collection($products), 'Best seller products retrieved successfully.');
    }

    private function flashSaleQuery()
    {
        return Promotion::query()
            ->where('type', PromotionType::FLASH_SALE)
            ->where('is_active', true);
    }

    /**
     * Today (WIB) while a flash sale is still running or upcoming today, otherwise the next date with one.
     */
    private function resolveNearestFlashSaleDate(): ?string
    {
        $next = $this->flashSaleQuery()
            ->where('ends_at', '>=', now())
            ->orderBy('starts_at')
            ->first();

        if (! $next) {
            return null;
        }

        return $next->starts_at->lte(now())
            ? now(self::TIMEZONE)->toDateString()
            : $next->starts_at->copy()->setTimezone(self::TIMEZONE)->toDateString();
    }

    /**
     * @return list<string>
     */
    private function availableFlashSaleDates(): array
    {
        $today = now(self::TIMEZONE)->toDateString();

        return $this->flashSaleQuery()
            ->where('ends_at', '>=', now())
            ->orderBy('starts_at')
            ->get(['starts_at'])
            ->map(fn (Promotion $promotion) => max($today, $promotion->starts_at->copy()->setTimezone(self::TIMEZONE)->toDateString()))
            ->unique()
            ->values()
            ->all();
    }
}
