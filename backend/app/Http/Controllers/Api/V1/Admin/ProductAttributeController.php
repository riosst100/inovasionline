<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\ProductAttribute;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProductAttributeController extends Controller
{
    public function index(): JsonResponse
    {
        $items = ProductAttribute::query()
            ->orderByDesc('is_system')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return ApiResponse::success($items, 'Product attributes retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:60', 'regex:/^[a-z][a-z0-9_]*$/', 'unique:product_attributes,code'],
            ...$this->commonRules(),
        ], [
            'code.regex' => 'Kode hanya boleh huruf kecil, angka, dan underscore, diawali huruf.',
            'code.unique' => 'Kode atribut sudah digunakan.',
        ]);

        $data['options'] = $this->normalizeOptions($data);
        $data['is_system'] = false;
        $data['sort_order'] = (int) ProductAttribute::max('sort_order') + 1;

        return ApiResponse::success(ProductAttribute::create($data), 'Product attribute created successfully.', [], 201);
    }

    public function update(Request $request, ProductAttribute $productAttribute): JsonResponse
    {
        if ($productAttribute->is_system) {
            // System attributes: only name/description (and active state of optional ones) can change.
            $data = $request->validate([
                'name' => ['required', 'string', 'max:100'],
                'description' => ['nullable', 'string', 'max:255'],
                'is_active' => ['sometimes', 'boolean'],
            ]);
            if ($productAttribute->is_required) {
                unset($data['is_active']);
            }
        } else {
            $data = $request->validate($this->commonRules());
            $data['options'] = $this->normalizeOptions($data);
        }

        $productAttribute->update($data);

        return ApiResponse::success($productAttribute->fresh(), 'Product attribute updated successfully.');
    }

    public function destroy(ProductAttribute $productAttribute): JsonResponse
    {
        if ($productAttribute->is_system) {
            return ApiResponse::error('Atribut sistem tidak dapat dihapus.', [], 422);
        }

        $productAttribute->delete();

        return ApiResponse::success(null, 'Product attribute deleted successfully.');
    }

    private function commonRules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100'],
            'type' => ['required', Rule::in(ProductAttribute::TYPES)],
            'options' => ['nullable', 'array', 'max:100'],
            'options.*' => ['string', 'max:100'],
            'description' => ['nullable', 'string', 'max:255'],
            'is_required' => ['sometimes', 'boolean'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    private function normalizeOptions(array $data): ?array
    {
        if (($data['type'] ?? null) !== 'select') {
            return null;
        }

        $options = array_values(array_unique(array_filter(array_map('trim', $data['options'] ?? []))));

        abort_if(count($options) === 0, 422, 'Atribut tipe pilihan wajib memiliki minimal satu opsi.');

        return $options;
    }
}
