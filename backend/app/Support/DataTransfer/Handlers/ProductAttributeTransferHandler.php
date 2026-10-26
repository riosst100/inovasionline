<?php

namespace App\Support\DataTransfer\Handlers;

use App\Models\ProductAttribute;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Rows are matched on `code`; unmatched rows create a custom attribute. `options` (type select) are separated by `|`.
 * As on the page, a system attribute only takes name, description and (when not required) is_active.
 */
class ProductAttributeTransferHandler implements TransferHandler
{
    private const OPTION_SEPARATOR = '|';

    public function label(): string
    {
        return 'Atribut Produk';
    }

    public function headers(): array
    {
        return ['code', 'name', 'type', 'options', 'description', 'is_required', 'is_active', 'sort_order'];
    }

    public function sampleRow(): array
    {
        return [
            // Deliberately not a real attribute, so importing the untouched template never overwrites data.
            'code' => 'contoh_atribut',
            'name' => 'Contoh Atribut',
            'type' => 'select',
            'options' => 'Pilihan A|Pilihan B',
            'description' => 'Hapus baris ini dan isi dengan data Anda',
            'is_required' => '0',
            'is_active' => '1',
            'sort_order' => '',
        ];
    }

    public function exportQuery(array $filters): Builder
    {
        return ProductAttribute::query()->orderByDesc('is_system')->orderBy('sort_order')->orderBy('name');
    }

    public function exportRow(Model $model): array
    {
        /** @var ProductAttribute $model */
        return [
            'code' => $model->code,
            'name' => $model->name,
            'type' => $model->type,
            'options' => $model->options ? implode(self::OPTION_SEPARATOR, $model->options) : null,
            'description' => $model->description,
            'is_required' => $model->is_required ? 1 : 0,
            'is_active' => $model->is_active ? 1 : 0,
            'sort_order' => $model->sort_order,
        ];
    }

    public function prepareImport(array $rows): array
    {
        return $rows;
    }

    public function importRow(array $row): string
    {
        $code = mb_strtolower(trim((string) ($row['code'] ?? '')));
        $name = trim((string) ($row['name'] ?? ''));
        if ($code === '') {
            throw new RowSkippedException('Kolom code wajib diisi.');
        }
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
            $data['is_active'] = self::bool($row['is_active']);
        }

        $attribute = ProductAttribute::query()->where('code', $code)->first();

        if ($attribute?->is_system) {
            if ($attribute->is_required) {
                unset($data['is_active']);
            }
            $attribute->update($data);

            return ImportResult::UPDATED;
        }

        if (! $attribute && (mb_strlen($code) > 60 || ! preg_match('/^[a-z][a-z0-9_]*$/', $code))) {
            throw new RowSkippedException('Kolom code hanya boleh huruf kecil, angka, dan underscore, diawali huruf (maks. 60).');
        }

        $type = mb_strtolower(trim((string) ($row['type'] ?? '')));
        if (! in_array($type, ProductAttribute::TYPES, true)) {
            throw new RowSkippedException('Kolom type harus salah satu dari: '.implode(', ', ProductAttribute::TYPES).'.');
        }
        $data['type'] = $type;
        $data['options'] = null;
        if ($type === 'select') {
            $options = array_values(array_unique(array_filter(array_map('trim', explode(self::OPTION_SEPARATOR, (string) ($row['options'] ?? ''))))));
            if (count($options) === 0) {
                throw new RowSkippedException('Atribut tipe select wajib memiliki minimal satu opsi (pisahkan dengan |).');
            }
            if (count($options) > 100 || collect($options)->contains(fn ($o) => mb_strlen($o) > 100)) {
                throw new RowSkippedException('Kolom options maksimal 100 opsi, masing-masing maksimal 100 karakter.');
            }
            $data['options'] = $options;
        }
        if (filled($row['is_required'] ?? null)) {
            $data['is_required'] = self::bool($row['is_required']);
        }
        if (filled($row['sort_order'] ?? null)) {
            if (! is_numeric($row['sort_order'])) {
                throw new RowSkippedException('Kolom sort_order harus berupa angka.');
            }
            $data['sort_order'] = (int) $row['sort_order'];
        }

        if ($attribute) {
            $attribute->update($data);

            return ImportResult::UPDATED;
        }

        ProductAttribute::create([
            'is_active' => true,
            'is_required' => false,
            'sort_order' => (int) ProductAttribute::max('sort_order') + 1,
            ...$data,
            'code' => $code,
            'is_system' => false,
        ]);

        return ImportResult::CREATED;
    }

    private static function bool(string $value): bool
    {
        return in_array(strtolower(trim($value)), ['1', 'true', 'yes', 'ya', 'aktif', 'active'], true);
    }
}
