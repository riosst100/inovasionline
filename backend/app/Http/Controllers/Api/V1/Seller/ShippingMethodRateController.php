<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\ShippingMethodRateRequest;
use App\Http\Resources\ShippingMethodRateResource;
use App\Models\ShippingMethod;
use App\Models\ShippingMethodRate;
use App\Models\ShippingRateTemplate;
use App\Models\Store;
use App\Support\Responses\ApiResponse;
use App\Support\Shipping\RateRowImportExport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ShippingMethodRateController extends Controller
{
    public function index(Request $request, ShippingMethod $shippingMethod): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod)) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $rates = RateRowImportExport::withNames($shippingMethod->rates()->orderBy('district_code')->get());

        return ApiResponse::success(ShippingMethodRateResource::collection($rates), 'Shipping rates retrieved successfully.');
    }

    public function store(ShippingMethodRateRequest $request, ShippingMethod $shippingMethod): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod)) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $rate = RateRowImportExport::upsert(
            $shippingMethod->rates(),
            $request->validated('district_code'),
            $request->validated('village_code'),
            (float) $request->validated('fee'),
        );

        return ApiResponse::success(new ShippingMethodRateResource($rate), 'Shipping rate saved successfully.', [], 201);
    }

    public function update(Request $request, ShippingMethod $shippingMethod, ShippingMethodRate $rate): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod) || $rate->shipping_method_id !== $shippingMethod->id) {
            return ApiResponse::error('This rate does not belong to your store.', [], 403);
        }

        $request->validate(['fee' => ['required', 'numeric', 'min:0']]);

        $rate->update(['fee' => $request->float('fee')]);

        return ApiResponse::success(new ShippingMethodRateResource($rate), 'Shipping rate updated successfully.');
    }

    public function destroy(Request $request, ShippingMethod $shippingMethod, ShippingMethodRate $rate): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod) || $rate->shipping_method_id !== $shippingMethod->id) {
            return ApiResponse::error('This rate does not belong to your store.', [], 403);
        }

        $rate->delete();

        return ApiResponse::success(null, 'Shipping rate deleted successfully.');
    }

    public function export(Request $request, ShippingMethod $shippingMethod)
    {
        if (! $this->authorize($request, $shippingMethod)) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $csv = RateRowImportExport::exportCsv($shippingMethod->rates()->orderBy('district_code')->get());

        return response()->streamDownload(
            fn () => print $csv,
            "shipping-rates-{$shippingMethod->id}.csv",
            ['Content-Type' => 'text/csv']
        );
    }

    public function import(Request $request, ShippingMethod $shippingMethod): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod)) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $request->validate(['file' => ['required', 'file', 'mimes:csv,txt', 'max:2048']]);

        $result = RateRowImportExport::importCsv($shippingMethod->rates(), $request->file('file'));

        return ApiResponse::success($result, 'Import completed.');
    }

    public function copyFromTemplate(Request $request, ShippingMethod $shippingMethod): JsonResponse
    {
        if (! $this->authorize($request, $shippingMethod)) {
            return ApiResponse::error('This shipping method does not belong to your store.', [], 403);
        }

        $request->validate(['shipping_rate_template_id' => ['required', 'string', 'exists:shipping_rate_templates,id']]);

        $template = ShippingRateTemplate::with('rows')->findOrFail($request->string('shipping_rate_template_id'));

        $count = 0;

        DB::transaction(function () use ($shippingMethod, $template, &$count) {
            foreach ($template->rows as $row) {
                RateRowImportExport::upsert($shippingMethod->rates(), $row->district_code, $row->village_code, (float) $row->fee);
                $count++;
            }
        });

        return ApiResponse::success(['copied' => $count], 'Template copied successfully.');
    }

    private function authorize(Request $request, ShippingMethod $shippingMethod): bool
    {
        /** @var Store $store */
        $store = $request->attributes->get('store');

        return $shippingMethod->store_id === $store->id;
    }
}
