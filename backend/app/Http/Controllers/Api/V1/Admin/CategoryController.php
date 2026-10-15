<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use App\Services\CategoryService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class CategoryController extends Controller
{
    public function __construct(private readonly CategoryService $categoryService) {}

    public function index(Request $request): JsonResponse
    {
        $categories = Category::query()
            ->when($request->string('status')->toString(), function ($query, $status) {
                if ($status === 'pending') {
                    $query->where('is_active', false);
                } elseif ($status === 'active') {
                    $query->where('is_active', true);
                }
            })
            ->orderBy('sort_order')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($categories, CategoryResource::class, 'Categories retrieved successfully.');
    }

    public function store(CategoryRequest $request): JsonResponse
    {
        $category = $this->categoryService->createFromAdmin($request->user(), $request->validated(), $request->file('image'));

        return ApiResponse::success(new CategoryResource($category), 'Category created successfully.', [], 201);
    }

    public function update(CategoryRequest $request, Category $category): JsonResponse
    {
        try {
            $category = $this->categoryService->update($category, $request->validated(), $request->file('image'));
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new CategoryResource($category), 'Category updated successfully.');
    }

    public function toggle(Category $category): JsonResponse
    {
        $category = $this->categoryService->toggleActive($category);

        return ApiResponse::success(
            new CategoryResource($category),
            $category->is_active ? 'Category enabled successfully.' : 'Category disabled successfully.'
        );
    }

    public function destroy(Category $category): JsonResponse
    {
        try {
            $this->categoryService->delete($category);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(null, 'Category deleted successfully.');
    }

    public function reorder(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array'],
            'ids.*' => ['string', 'exists:categories,id'],
        ]);

        $this->categoryService->reorder($data['ids']);

        return ApiResponse::success(null, 'Categories reordered successfully.');
    }

    public function approve(Category $category): JsonResponse
    {
        try {
            $category = $this->categoryService->approve($category);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new CategoryResource($category), 'Category approved successfully.');
    }
}
