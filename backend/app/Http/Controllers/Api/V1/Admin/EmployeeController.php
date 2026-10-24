<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class EmployeeController extends Controller
{
    public function index(): JsonResponse
    {
        $items = Employee::query()->orderByDesc('is_active')->orderBy('name')->get();

        return ApiResponse::success([
            'items' => $items,
            // Suggestions for the position field.
            'positions' => Employee::query()->distinct()->orderBy('position')->pluck('position'),
            'summary' => [
                'active' => $items->where('is_active', true)->count(),
                'monthly_total' => (float) $items->where('is_active', true)->where('salary_type', 'monthly')->sum('salary_amount'),
            ],
        ], 'Employees retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $employee = Employee::create($request->validate($this->rules()));

        return ApiResponse::success($employee, 'Karyawan berhasil ditambahkan.', [], 201);
    }

    public function update(Request $request, Employee $employee): JsonResponse
    {
        $employee->update($request->validate($this->rules()));

        return ApiResponse::success($employee->fresh(), 'Karyawan berhasil diperbarui.');
    }

    public function destroy(Employee $employee): JsonResponse
    {
        $employee->delete();

        return ApiResponse::success(null, 'Karyawan berhasil dihapus.');
    }

    private function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:150'],
            'phone' => ['nullable', 'string', 'max:30'],
            'position' => ['required', 'string', 'max:100'],
            'salary_type' => ['required', Rule::in(Employee::SALARY_TYPES)],
            'salary_amount' => ['required', 'numeric', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'notes' => ['nullable', 'string', 'max:255'],
        ];
    }
}
