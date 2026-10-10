<?php

namespace App\Http\Controllers\Api\V1\Seller;

use App\Http\Controllers\Controller;
use App\Http\Requests\Seller\CategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use App\Services\CategoryService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function __construct(private readonly CategoryService $categoryService) {}

    public function index(Request $request): JsonResponse
    {
        $categories = Category::query()
            ->where(function ($query) use ($request) {
                $query->where('is_active', true)
                    ->orWhere('created_by', $request->user()->id);
            })
            ->orderBy('sort_order')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($categories, CategoryResource::class, 'Categories retrieved successfully.');
    }

    public function store(CategoryRequest $request): JsonResponse
    {
        $category = $this->categoryService->createFromSeller($request->user(), $request->validated());

        return ApiResponse::success(new CategoryResource($category), 'Category submitted for approval.', [], 201);
    }
}
