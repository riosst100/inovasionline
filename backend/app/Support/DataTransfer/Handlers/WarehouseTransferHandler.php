<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Warehouse;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use App\Support\Warehouses\WarehouseCoverage;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Validation\ValidationException;
use Laravolt\Indonesia\Models\Village;

/**
 * Rows are matched on `code`. `coverage` lists district (kecamatan) and/or
 * village (desa) codes separated by ";" — when the column is present it
 * replaces the warehouse's coverage (empty clears it).
 */
class WarehouseTransferHandler implements TransferHandler
{
    private const LIMITS = [
        'name' => 120, 'address' => 255, 'city' => 100, 'province' => 100, 'postal_code' => 10,
        'contact_name' => 100, 'contact_phone' => 30, 'notes' => 255,
    ];

    public function label(): string
    {
        return 'Gudang';
    }

    public function headers(): array
    {
        return [
            'code', 'name', 'address', 'city', 'province', 'postal_code', 'latitude', 'longitude',
            'contact_name', 'contact_phone', 'notes', 'is_active', 'coverage',
        ];
    }

    public function sampleRow(): array
    {
        return [
            'code' => 'CONTOH-01',
            'name' => 'Gudang Contoh',
            'address' => 'Jl. Contoh No. 1',
            'city' => 'Tegal',
            'province' => 'Jawa Tengah',
            'postal_code' => '52111',
            'latitude' => '-6.8694',
            'longitude' => '109.1402',
            'contact_name' => 'Budi',
            'contact_phone' => '081234567890',
            'notes' => 'Hapus baris ini dan isi dengan data Anda',
            'is_active' => '1',
            'coverage' => null,
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return Warehouse::query()->with('coverage')->orderBy('code');
    }

    public function exportRow(Model $model): array
    {
        /** @var Warehouse $model */
        $row = ['code' => $model->code];
        foreach (array_keys(self::LIMITS) as $field) {
            $row[$field] = $model->{$field};
        }

        return [
            ...$row,
            'latitude' => $model->latitude,
            'longitude' => $model->longitude,
            'is_active' => $model->is_active ? 1 : 0,
            'coverage' => $model->coverage
                ->map(fn ($c) => $c->village_code ? trim($c->village_code) : trim($c->district_code))
                ->implode(';') ?: null,
        ];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $code = strtoupper(trim((string) ($row['code'] ?? '')));
        if ($code === '') {
            throw new RowSkippedException('Kolom code wajib diisi.');
        }
        if (mb_strlen($code) > 30 || ! preg_match('/^[A-Z0-9][A-Z0-9_-]*$/', $code)) {
            throw new RowSkippedException('Kolom code hanya boleh huruf besar, angka, strip, dan underscore (maks. 30).');
        }

        $warehouse = Warehouse::query()->where('code', $code)->first();

        $data = [];
        foreach (self::LIMITS as $field => $max) {
            if (array_key_exists($field, $row)) {
                if ($row[$field] !== null && mb_strlen($row[$field]) > $max) {
                    throw new RowSkippedException("Kolom {$field} maksimal {$max} karakter.");
                }
                $data[$field] = $row[$field];
            }
        }
        if (blank($data['name'] ?? $warehouse?->name)) {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }
        foreach (['latitude' => 90, 'longitude' => 180] as $field => $bound) {
            if (array_key_exists($field, $row)) {
                $data[$field] = $this->coordinate($row[$field], $field, $bound);
            }
        }
        if (filled($row['is_active'] ?? null)) {
            $data['is_active'] = in_array(strtolower(trim($row['is_active'])), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
        }

        $coverage = array_key_exists('coverage', $row) ? $this->coverage($row['coverage']) : null;

        if ($warehouse) {
            $warehouse->update($data);
            $result = ImportResult::UPDATED;
        } else {
            $warehouse = Warehouse::create(['is_active' => true, ...$data, 'code' => $code]);
            $result = ImportResult::CREATED;
        }

        if ($coverage !== null) {
            WarehouseCoverage::sync($warehouse, $coverage);
        }

        return $result;
    }

    /** @return list<array{district_code: string, village_code: ?string}> */
    private function coverage(?string $value): array
    {
        $codes = collect(preg_split('/[;,\s]+/', (string) $value, -1, PREG_SPLIT_NO_EMPTY))
            ->map(fn ($c) => str_replace('.', '', $c))
            ->unique();

        $invalid = $codes->reject(fn ($c) => ctype_digit($c));
        if ($invalid->isNotEmpty()) {
            throw new RowSkippedException('Kode wilayah tidak valid di coverage: '.$invalid->take(5)->implode(', ').'.');
        }

        // Code lengths differ per region dataset, so a code is a village if the villages table knows it.
        $villageDistricts = Village::query()->whereIn('code', $codes)->pluck('district_code', 'code')
            ->mapWithKeys(fn ($d, $c) => [trim($c) => trim($d)]);

        try {
            return WarehouseCoverage::normalize($codes->map(fn ($c) => isset($villageDistricts[$c])
                ? ['district_code' => $villageDistricts[$c], 'village_code' => $c]
                : ['district_code' => $c, 'village_code' => null]));
        } catch (ValidationException $e) {
            throw new RowSkippedException(collect($e->errors())->flatten()->first() ?: 'Coverage tidak valid.');
        }
    }

    private function coordinate(?string $value, string $field, int $bound): ?float
    {
        if (blank($value)) {
            return null;
        }
        $value = str_replace(',', '.', trim($value));
        if (! is_numeric($value) || abs((float) $value) > $bound) {
            throw new RowSkippedException("Kolom {$field} harus angka antara -{$bound} dan {$bound}.");
        }

        return (float) $value;
    }
}
