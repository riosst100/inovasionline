<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ShippingRateTemplateRequest;
use App\Http\Resources\ShippingRateTemplateResource;
use App\Models\ShippingRateTemplate;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class ShippingRateTemplateController extends Controller
{
    public function index(): JsonResponse
    {
        $templates = ShippingRateTemplate::withCount('rows')->latest()->get();

        return ApiResponse::success(ShippingRateTemplateResource::collection($templates), 'Shipping rate templates retrieved successfully.');
    }

    public function store(ShippingRateTemplateRequest $request): JsonResponse
    {
        $template = ShippingRateTemplate::create($request->validated());

        return ApiResponse::success(new ShippingRateTemplateResource($template), 'Shipping rate template created successfully.', [], 201);
    }

    public function update(ShippingRateTemplateRequest $request, ShippingRateTemplate $shippingRateTemplate): JsonResponse
    {
        $shippingRateTemplate->update($request->validated());

        return ApiResponse::success(new ShippingRateTemplateResource($shippingRateTemplate), 'Shipping rate template updated successfully.');
    }

    public function destroy(ShippingRateTemplate $shippingRateTemplate): JsonResponse
    {
        $shippingRateTemplate->delete();

        return ApiResponse::success(null, 'Shipping rate template deleted successfully.');
    }
}
