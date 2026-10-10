<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Resources\ShippingRateTemplateResource;
use App\Models\ShippingRateTemplate;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

class ShippingRateTemplateReadController extends Controller
{
    public function index(): JsonResponse
    {
        $templates = ShippingRateTemplate::withCount('rows')->orderBy('name')->get();

        return ApiResponse::success(ShippingRateTemplateResource::collection($templates), 'Shipping rate templates retrieved successfully.');
    }
}
