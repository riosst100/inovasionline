<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\BannerRequest;
use App\Http\Resources\BannerResource;
use App\Models\Banner;
use App\Services\BannerService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BannerController extends Controller
{
    public function __construct(private readonly BannerService $bannerService) {}

    public function index(): JsonResponse
    {
        $banners = Banner::query()->orderBy('sort_order')->get();

        return ApiResponse::success(BannerResource::collection($banners), 'Banners retrieved successfully.');
    }

    public function store(BannerRequest $request): JsonResponse
    {
        $banner = $this->bannerService->create($request->validated(), $request->file('image'));

        return ApiResponse::success(new BannerResource($banner), 'Banner created successfully.', [], 201);
    }

    public function update(BannerRequest $request, Banner $banner): JsonResponse
    {
        $banner = $this->bannerService->update($banner, $request->validated(), $request->file('image'));

        return ApiResponse::success(new BannerResource($banner), 'Banner updated successfully.');
    }

    public function reorder(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array'],
            'ids.*' => ['string', 'exists:banners,id'],
        ]);

        $this->bannerService->reorder($data['ids']);

        return ApiResponse::success(null, 'Banners reordered successfully.');
    }

    public function destroy(Banner $banner): JsonResponse
    {
        $this->bannerService->delete($banner);

        return ApiResponse::success(null, 'Banner deleted successfully.');
    }
}
