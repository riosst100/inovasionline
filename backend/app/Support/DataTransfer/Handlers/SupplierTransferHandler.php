<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\Supplier;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Rows are matched on `id`, then on `name` (case-insensitive); unmatched rows
 * create a supplier.
 */
class SupplierTransferHandler implements TransferHandler
{
    private const LIMITS = [
        'contact_name' => 100, 'phone' => 30, 'email' => 150, 'address' => 255, 'notes' => 255,
    ];

    public function label(): string
    {
        return 'Supplier';
    }

    public function headers(): array
    {
        return ['id', 'name', 'contact_name', 'phone', 'email', 'address', 'notes', 'is_active'];
    }

    public function sampleRow(): array
    {
        return [
            'name' => 'Contoh Supplier',
            'contact_name' => 'Budi',
            'phone' => '081234567890',
            'email' => 'supplier@contoh.test',
            'address' => 'Jl. Contoh No. 1',
            'notes' => 'Hapus baris ini dan isi dengan data Anda',
            'is_active' => '1',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return Supplier::query()->orderBy('name')->orderBy('id');
    }

    public function exportRow(Model $model): array
    {
        /** @var Supplier $model */
        $row = ['id' => $model->id, 'name' => $model->name];
        foreach (array_keys(self::LIMITS) as $field) {
            $row[$field] = $model->{$field};
        }

        return [...$row, 'is_active' => $model->is_active ? 1 : 0];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        if (mb_strlen($name) > 150) {
            throw new RowSkippedException('Kolom name maksimal 150 karakter.');
        }

        if (filled($row['id'] ?? null)) {
            $supplier = Supplier::query()->find(trim($row['id']))
                ?? throw new RowSkippedException("Supplier dengan id {$row['id']} tidak ditemukan. Kosongkan kolom id untuk membuat supplier baru.");
        } else {
            $supplier = $name !== '' ? Supplier::query()->whereRaw('lower(name) = ?', [mb_strtolower($name)])->first() : null;
        }

        if ($name === '' && ! $supplier) {
            throw new RowSkippedException('Kolom name wajib diisi.');
        }

        $data = $name !== '' ? ['name' => $name] : [];
        foreach (self::LIMITS as $field => $max) {
            if (array_key_exists($field, $row)) {
                if ($row[$field] !== null && mb_strlen($row[$field]) > $max) {
                    throw new RowSkippedException("Kolom {$field} maksimal {$max} karakter.");
                }
                $data[$field] = $row[$field];
            }
        }
        if (filled($data['email'] ?? null) && ! filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
            throw new RowSkippedException('Kolom email tidak valid.');
        }
        if (filled($row['is_active'] ?? null)) {
            $data['is_active'] = in_array(strtolower(trim($row['is_active'])), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
        }

        if ($supplier) {
            $supplier->update($data);

            return ImportResult::UPDATED;
        }

        Supplier::create(['is_active' => true, ...$data]);

        return ImportResult::CREATED;
    }
}
