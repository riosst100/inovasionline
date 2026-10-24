<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Brand;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Rows are matched on `name` (case-insensitive, brand names are unique);
 * unmatched rows create a brand.
 */
class BrandTransferHandler implements TransferHandler
{
    public function label(): string
    {
        return 'Brand';
    }

    public function headers(): array
    {
        return ['name', 'description', 'is_active'];
    }

    public function sampleRow(): array
    {
        return [
            // Deliberately not a real brand, so importing the untouched template never overwrites data.
            'name' => 'Contoh Brand',
            'description' => 'Hapus baris ini dan isi dengan data Anda',
            'is_active' => '1',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return Brand::query()->orderBy('name');
    }

    public function exportRow(Model $model): array
    {
        /** @var Brand $model */
        return [
            'name' => $model->name,
            'description' => $model->description,
            'is_active' => $model->is_active ? 1 : 0,
        ];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        if ($name === '') {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }
        if (mb_strlen($name) > 100) {
            throw new RowSkippedException('Kolom name maksimal 100 karakter.');
        }

        $data = ['name' => $name];
        if (array_key_exists('description', $row)) {
            if ($row['description'] !== null && mb_strlen($row['description']) > 255) {
                throw new RowSkippedException('Kolom description maksimal 255 karakter.');
            }
            $data['description'] = $row['description'];
        }
        if (filled($row['is_active'] ?? null)) {
            $data['is_active'] = in_array(strtolower(trim($row['is_active'])), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
        }

        $brand = Brand::query()->whereRaw('lower(name) = ?', [mb_strtolower($name)])->first();
        if ($brand) {
            $brand->update($data);

            return ImportResult::UPDATED;
        }

        Brand::create(['is_active' => true, ...$data]);

        return ImportResult::CREATED;
    }
}
