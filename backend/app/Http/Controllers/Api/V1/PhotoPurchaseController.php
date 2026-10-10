<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\PhotoPurchaseRequest;
use App\Http\Resources\PhotoPurchaseResource;
use App\Models\Photo;
use App\Services\PhotoPurchaseService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class PhotoPurchaseController extends Controller
{
    public function __construct(private readonly PhotoPurchaseService $photoPurchaseService) {}

    public function index(Request $request): JsonResponse
    {
        $paginator = $request->user()->photoPurchases()
            ->with('photo.photographer', 'photo.event')
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ApiResponse::paginated($paginator, PhotoPurchaseResource::class, 'Photo purchases retrieved successfully.');
    }

    public function store(PhotoPurchaseRequest $request): JsonResponse
    {
        $photo = Photo::findOrFail($request->validated('photo_id'));

        try {
            $purchase = $this->photoPurchaseService->purchase(
                $request->user(),
                $photo,
                $request->integer('matched_face_index', 0)
            );
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new PhotoPurchaseResource($purchase->load('photo')), 'Photo purchased successfully.', [], 201);
    }
}
