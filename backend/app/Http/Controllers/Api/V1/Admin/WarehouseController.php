<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class WarehouseController extends Controller
{
    public function index(): JsonResponse
    {
        $items = Warehouse::query()->orderBy('name')->get();

        return ApiResponse::success($items, 'Warehouses retrieved successfully.');
    }

    public function show(Warehouse $warehouse): JsonResponse
    {
        return ApiResponse::success($warehouse, 'Warehouse retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:30', 'regex:/^[A-Z0-9][A-Z0-9_-]*$/', 'unique:warehouses,code'],
            ...$this->commonRules(),
        ], [
            'code.regex' => 'Kode hanya boleh huruf besar, angka, strip, dan underscore.',
            'code.unique' => 'Kode gudang sudah digunakan.',
        ]);

        return ApiResponse::success(Warehouse::create($data), 'Warehouse created successfully.', [], 201);
    }

    public function update(Request $request, Warehouse $warehouse): JsonResponse
    {
        $data = $request->validate([
            'code' => ['sometimes', 'string', 'max:30', 'regex:/^[A-Z0-9][A-Z0-9_-]*$/', Rule::unique('warehouses', 'code')->ignore($warehouse->id)],
            ...$this->commonRules(),
        ], [
            'code.regex' => 'Kode hanya boleh huruf besar, angka, strip, dan underscore.',
            'code.unique' => 'Kode gudang sudah digunakan.',
        ]);

        $warehouse->update($data);

        return ApiResponse::success($warehouse->fresh(), 'Warehouse updated successfully.');
    }

    public function destroy(Warehouse $warehouse): JsonResponse
    {
        // TODO: tolak penghapusan bila gudang masih memiliki stok setelah relasi stok dibuat.
        $warehouse->delete();

        return ApiResponse::success(null, 'Warehouse deleted successfully.');
    }

    private function commonRules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'type' => ['required', Rule::in(Warehouse::TYPES)],
            'address' => ['nullable', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:100'],
            'province' => ['nullable', 'string', 'max:100'],
            'postal_code' => ['nullable', 'string', 'max:10'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'contact_name' => ['nullable', 'string', 'max:100'],
            'contact_phone' => ['nullable', 'string', 'max:30'],
            'notes' => ['nullable', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
