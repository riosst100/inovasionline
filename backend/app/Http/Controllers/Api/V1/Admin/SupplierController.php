<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    public function index(): JsonResponse
    {
        $items = Supplier::query()->withCount('products')->orderBy('name')->get();

        return ApiResponse::success($items, 'Suppliers retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $supplier = Supplier::create($request->validate($this->rules()));

        return ApiResponse::success($supplier, 'Supplier created successfully.', [], 201);
    }

    public function update(Request $request, Supplier $supplier): JsonResponse
    {
        $supplier->update($request->validate($this->rules()));

        return ApiResponse::success($supplier->fresh(), 'Supplier updated successfully.');
    }

    public function destroy(Supplier $supplier): JsonResponse
    {
        if ($supplier->bills()->exists()) {
            return ApiResponse::error('Supplier ini masih memiliki tagihan dan tidak dapat dihapus. Nonaktifkan saja.', [], 422);
        }

        // Products keep existing; their supplier_id is nulled by the FK.
        $supplier->delete();

        return ApiResponse::success(null, 'Supplier deleted successfully.');
    }

    private function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:150'],
            'contact_name' => ['nullable', 'string', 'max:100'],
            'phone' => ['nullable', 'string', 'max:30'],
            'email' => ['nullable', 'email', 'max:150'],
            'address' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
