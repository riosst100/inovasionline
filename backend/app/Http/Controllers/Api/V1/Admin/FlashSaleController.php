<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\FlashSaleRequest;
use App\Http\Resources\FlashSaleResource;
use App\Models\Promotion;
use App\Support\Enums\PromotionType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Flash sales are promotions of type flash_sale with a fixed price per product.
 */
class FlashSaleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $now = now();

        $flashSales = Promotion::query()
            ->where('type', PromotionType::FLASH_SALE)
            ->withCount('products')
            ->when($request->string('search')->toString(), fn ($q, $search) => $q->where('name', 'ilike', "%{$search}%"))
            ->when($request->string('status')->toString(), fn ($q, $status) => match ($status) {
                'running' => $q->where('is_active', true)->where('starts_at', '<=', $now)->where('ends_at', '>=', $now),
                'upcoming' => $q->where('is_active', true)->where('starts_at', '>', $now),
                'ended' => $q->where('ends_at', '<', $now),
                'inactive' => $q->where('is_active', false),
                default => $q,
            })
            ->orderByDesc('starts_at')
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($flashSales, FlashSaleResource::class, 'Flash sales retrieved successfully.');
    }

    public function show(Promotion $flashSale): JsonResponse
    {
        $this->ensureFlashSale($flashSale);

        return ApiResponse::success(new FlashSaleResource($this->loadDetail($flashSale)), 'Flash sale retrieved successfully.');
    }

    public function store(FlashSaleRequest $request): JsonResponse
    {
        $flashSale = DB::transaction(function () use ($request) {
            $flashSale = Promotion::create([
                ...$this->attributes($request),
                'type' => PromotionType::FLASH_SALE,
            ]);
            $flashSale->products()->sync($this->productPivot($request));

            return $flashSale;
        });

        return ApiResponse::success(new FlashSaleResource($this->loadDetail($flashSale)), 'Flash sale berhasil dibuat.', [], 201);
    }

    public function update(FlashSaleRequest $request, Promotion $flashSale): JsonResponse
    {
        $this->ensureFlashSale($flashSale);

        DB::transaction(function () use ($request, $flashSale) {
            $flashSale->update($this->attributes($request));
            $flashSale->products()->sync($this->productPivot($request));
        });

        return ApiResponse::success(new FlashSaleResource($this->loadDetail($flashSale)), 'Flash sale berhasil diperbarui.');
    }

    public function toggle(Promotion $flashSale): JsonResponse
    {
        $this->ensureFlashSale($flashSale);

        $flashSale->update(['is_active' => ! $flashSale->is_active]);

        return ApiResponse::success(new FlashSaleResource($flashSale->loadCount('products')), 'Status flash sale berhasil diperbarui.');
    }

    public function destroy(Promotion $flashSale): JsonResponse
    {
        $this->ensureFlashSale($flashSale);

        $flashSale->delete();

        return ApiResponse::success(null, 'Flash sale berhasil dihapus.');
    }

    private function attributes(FlashSaleRequest $request): array
    {
        return [
            'name' => $request->validated('name'),
            'starts_at' => $request->date('starts_at')->utc(),
            'ends_at' => $request->date('ends_at')->utc(),
            'is_active' => $request->boolean('is_active', true),
        ];
    }

    /**
     * @return array<string, array{flash_sale_price: float}>
     */
    private function productPivot(FlashSaleRequest $request): array
    {
        return collect($request->validated('products'))
            ->mapWithKeys(fn (array $row) => [$row['product_id'] => ['flash_sale_price' => (float) $row['flash_sale_price']]])
            ->all();
    }

    private function loadDetail(Promotion $flashSale): Promotion
    {
        return $flashSale->load([
            'products' => fn ($q) => $q->orderBy('name'),
            'products.images' => fn ($q) => $q->orderByDesc('is_primary')->orderBy('sort_order'),
        ])->loadCount('products');
    }

    private function ensureFlashSale(Promotion $promotion): void
    {
        if ($promotion->type !== PromotionType::FLASH_SALE) {
            throw new NotFoundHttpException;
        }
    }
}
