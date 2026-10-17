<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use App\Support\Responses\ApiResponse;
use App\Support\Warehouses\WarehouseCoverage;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Village;

class WarehouseController extends Controller
{
    public function index(): JsonResponse
    {
        $items = Warehouse::query()->with('coverage')->orderBy('name')->get();

        return ApiResponse::success($this->serialize($items), 'Warehouses retrieved successfully.');
    }

    public function show(Warehouse $warehouse): JsonResponse
    {
        return ApiResponse::success($this->serialize($warehouse->load('coverage')), 'Warehouse retrieved successfully.');
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

        $coverage = $this->normalizeCoverage($data);
        unset($data['coverage']);

        $warehouse = DB::transaction(function () use ($data, $coverage) {
            $warehouse = Warehouse::create($data);
            $this->syncCoverage($warehouse, $coverage);

            return $warehouse;
        });

        return ApiResponse::success($this->serialize($warehouse->load('coverage')), 'Warehouse created successfully.', [], 201);
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

        $coverage = array_key_exists('coverage', $data) ? $this->normalizeCoverage($data) : null;
        unset($data['coverage']);

        DB::transaction(function () use ($warehouse, $data, $coverage) {
            $warehouse->update($data);
            if ($coverage !== null) {
                $this->syncCoverage($warehouse, $coverage);
            }
        });

        return ApiResponse::success($this->serialize($warehouse->fresh('coverage')), 'Warehouse updated successfully.');
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
            'coverage' => ['sometimes', 'array', 'max:2000'],
            'coverage.*.district_code' => ['required', 'string', 'max:7'],
            'coverage.*.village_code' => ['nullable', 'string', 'max:10'],
        ];
    }

    /** @return list<array{district_code: string, village_code: ?string}> */
    private function normalizeCoverage(array $data): array
    {
        return WarehouseCoverage::normalize($data['coverage'] ?? []);
    }

    private function syncCoverage(Warehouse $warehouse, array $coverage): void
    {
        WarehouseCoverage::sync($warehouse, $coverage);
    }

    /**
     * Attach readable district/village names to each warehouse's coverage.
     */
    private function serialize(Warehouse|Collection $input): array
    {
        $single = $input instanceof Warehouse;
        $warehouses = $single ? collect([$input]) : $input;

        $all = $warehouses->flatMap->coverage;
        $districts = District::query()->whereIn('code', $all->pluck('district_code')->unique())->pluck('name', 'code')
            ->mapWithKeys(fn ($n, $c) => [trim($c) => $n]);
        $villages = Village::query()->whereIn('code', $all->pluck('village_code')->filter()->unique())->pluck('name', 'code')
            ->mapWithKeys(fn ($n, $c) => [trim($c) => $n]);

        $result = $warehouses->map(function (Warehouse $w) use ($districts, $villages) {
            $row = $w->toArray();
            $row['coverage'] = $w->coverage
                ->map(function ($c) use ($districts, $villages) {
                    $d = trim($c->district_code);
                    $v = $c->village_code ? trim($c->village_code) : null;

                    return [
                        'district_code' => $d,
                        'district_name' => $districts[$d] ?? $d,
                        'village_code' => $v,
                        'village_name' => $v ? ($villages[$v] ?? $v) : null,
                    ];
                })
                ->sortBy([['district_name', 'asc'], ['village_name', 'asc']])
                ->values()
                ->all();

            return $row;
        })->all();

        return $single ? $result[0] : $result;
    }
}
