<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class BrandController extends Controller
{
    public function index(): JsonResponse
    {
        $items = Brand::query()->withCount('products')->orderBy('name')->get();

        return ApiResponse::success($items, 'Brands retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $brand = Brand::create($request->validate($this->rules(), $this->messages()));

        return ApiResponse::success($brand, 'Brand created successfully.', [], 201);
    }

    public function update(Request $request, Brand $brand): JsonResponse
    {
        $brand->update($request->validate($this->rules($brand), $this->messages()));

        return ApiResponse::success($brand->fresh(), 'Brand updated successfully.');
    }

    public function destroy(Brand $brand): JsonResponse
    {
        // Products keep existing; their brand_id is nulled by the FK.
        $brand->delete();

        return ApiResponse::success(null, 'Brand deleted successfully.');
    }

    private function rules(?Brand $brand = null): array
    {
        return [
            'name' => ['required', 'string', 'max:100', Rule::unique('brands', 'name')->ignore($brand?->id)],
            'description' => ['nullable', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    private function messages(): array
    {
        return ['name.unique' => 'Nama brand sudah digunakan.'];
    }
}
