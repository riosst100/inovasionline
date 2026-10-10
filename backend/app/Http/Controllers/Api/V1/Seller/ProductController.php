<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\ProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Store;
use App\Services\ProductService;
use App\Support\Products\ProductImportExport;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function __construct(private readonly ProductService $productService) {}

    public function index(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $products = $store->products()
            ->with('images')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($products, ProductResource::class, 'Products retrieved successfully.');
    }

    public function store(ProductRequest $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $product = $this->productService->create(
            $store,
            $request->safe()->except('images'),
            $request->file('images', [])
        );

        return ApiResponse::success(new ProductResource($product), 'Product created successfully.', [], 201);
    }

    public function show(Request $request, string $product): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $product = $store->products()->with('images')->findOrFail($product);

        return ApiResponse::success(new ProductResource($product), 'Product retrieved successfully.');
    }

    public function update(ProductRequest $request, string $product): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $product = $store->products()->findOrFail($product);

        $product = $this->productService->update(
            $product,
            $request->safe()->except(['images', 'existing_images']),
            $request->file('images', []),
            $request->input('existing_images')
        );

        return ApiResponse::success(new ProductResource($product), 'Product updated successfully.');
    }

    public function export(Request $request)
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $format = $request->string('format', 'csv')->lower()->value();
        $products = $store->products()->with('category')->latest()->get();

        if ($format === 'xlsx') {
            $contents = ProductImportExport::exportXlsx($products);
            $filename = "products-{$store->id}.xlsx";
            $contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } else {
            $contents = ProductImportExport::exportCsv($products);
            $filename = "products-{$store->id}.csv";
            $contentType = 'text/csv';
        }

        return response()->streamDownload(
            fn () => print $contents,
            $filename,
            ['Content-Type' => $contentType]
        );
    }

    public function import(Request $request): JsonResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        $request->validate(['file' => ['required', 'file', 'mimes:csv,txt,xlsx,xls', 'max:10240']]);

        $result = ProductImportExport::import($store, $request->file('file'), $this->productService);

        return ApiResponse::success($result, 'Import completed.');
    }
}
