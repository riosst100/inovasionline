<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ShippingRateTemplateRowRequest;
use App\Http\Resources\ShippingRateTemplateRowResource;
use App\Models\ShippingRateTemplate;
use App\Models\ShippingRateTemplateRow;
use App\Support\Responses\ApiResponse;
use App\Support\Shipping\RateRowImportExport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShippingRateTemplateRowController extends Controller
{
    public function index(ShippingRateTemplate $template): JsonResponse
    {
        $rows = RateRowImportExport::withNames($template->rows()->orderBy('district_code')->get());

        return ApiResponse::success(ShippingRateTemplateRowResource::collection($rows), 'Template rows retrieved successfully.');
    }

    public function store(ShippingRateTemplateRowRequest $request, ShippingRateTemplate $template): JsonResponse
    {
        $row = RateRowImportExport::upsert(
            $template->rows(),
            $request->validated('district_code'),
            $request->validated('village_code'),
            (float) $request->validated('fee'),
        );

        return ApiResponse::success(new ShippingRateTemplateRowResource($row), 'Template row saved successfully.', [], 201);
    }

    public function update(Request $request, ShippingRateTemplate $template, ShippingRateTemplateRow $row): JsonResponse
    {
        if ($row->shipping_rate_template_id !== $template->id) {
            return ApiResponse::error('This row does not belong to this template.', [], 403);
        }

        $request->validate(['fee' => ['required', 'numeric', 'min:0']]);

        $row->update(['fee' => $request->float('fee')]);

        return ApiResponse::success(new ShippingRateTemplateRowResource($row), 'Template row updated successfully.');
    }

    public function destroy(ShippingRateTemplate $template, ShippingRateTemplateRow $row): JsonResponse
    {
        if ($row->shipping_rate_template_id !== $template->id) {
            return ApiResponse::error('This row does not belong to this template.', [], 403);
        }

        $row->delete();

        return ApiResponse::success(null, 'Template row deleted successfully.');
    }

    public function export(ShippingRateTemplate $template)
    {
        $csv = RateRowImportExport::exportCsv($template->rows()->orderBy('district_code')->get());

        return response()->streamDownload(
            fn () => print $csv,
            "shipping-rate-template-{$template->id}.csv",
            ['Content-Type' => 'text/csv']
        );
    }

    public function import(Request $request, ShippingRateTemplate $template): JsonResponse
    {
        $request->validate(['file' => ['required', 'file', 'mimes:csv,txt', 'max:2048']]);

        $result = RateRowImportExport::importCsv($template->rows(), $request->file('file'));

        return ApiResponse::success($result, 'Import completed.');
    }
}
