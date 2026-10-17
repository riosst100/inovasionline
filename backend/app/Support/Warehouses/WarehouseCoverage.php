<?php

namespace App\Support\Warehouses;

use App\Models\Warehouse;
use App\Models\WarehouseCoverageArea;
use Illuminate\Validation\ValidationException;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Village;

/**
 * Validates and stores the districts/villages a warehouse serves. Shared by
 * the admin warehouse form and the warehouse CSV/XLSX import.
 */
class WarehouseCoverage
{
    /**
     * Validate the requested areas against the region tables and collapse them:
     * a whole-district entry makes that district's individual villages redundant.
     *
     * @param  iterable<array{district_code: string, village_code?: ?string}>  $areas
     * @return list<array{district_code: string, village_code: ?string}>
     *
     * @throws ValidationException
     */
    public static function normalize(iterable $areas): array
    {
        $rows = collect($areas)
            ->map(fn ($r) => [
                'district_code' => trim($r['district_code']),
                'village_code' => isset($r['village_code']) ? trim($r['village_code']) : null,
            ])
            ->unique(fn ($r) => $r['district_code'].'|'.$r['village_code'])
            ->values();

        $districtCodes = $rows->pluck('district_code')->unique();
        $knownDistricts = District::query()->whereIn('code', $districtCodes)->pluck('code');
        if ($knownDistricts->count() !== $districtCodes->count()) {
            throw ValidationException::withMessages(['coverage' => 'Terdapat kecamatan yang tidak valid.']);
        }

        $villageCodes = $rows->pluck('village_code')->filter()->unique();
        if ($villageCodes->isNotEmpty()) {
            // char() columns come back space-padded, so compare trimmed codes.
            $villageDistrict = Village::query()->whereIn('code', $villageCodes)->pluck('district_code', 'code')
                ->mapWithKeys(fn ($d, $c) => [trim($c) => trim($d)]);
            foreach ($rows->whereNotNull('village_code') as $r) {
                if (($villageDistrict[$r['village_code']] ?? null) !== $r['district_code']) {
                    throw ValidationException::withMessages(['coverage' => 'Terdapat desa yang tidak valid atau tidak sesuai kecamatannya.']);
                }
            }
        }

        $wholeDistricts = $rows->whereNull('village_code')->pluck('district_code');

        return $rows
            ->reject(fn ($r) => $r['village_code'] !== null && $wholeDistricts->contains($r['district_code']))
            ->values()
            ->all();
    }

    /** @param  list<array{district_code: string, village_code: ?string}>  $coverage */
    public static function sync(Warehouse $warehouse, array $coverage): void
    {
        $warehouse->coverage()->delete();

        if ($coverage === []) {
            return;
        }

        $now = now();
        WarehouseCoverageArea::insert(array_map(fn ($r) => [
            'warehouse_id' => $warehouse->id,
            'district_code' => $r['district_code'],
            'village_code' => $r['village_code'],
            'created_at' => $now,
            'updated_at' => $now,
        ], $coverage));
    }
}
