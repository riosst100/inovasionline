<?php

namespace App\Support\Products;

use App\Models\Category;
use App\Models\Product;
use App\Models\Store;
use App\Services\ProductService;
use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;

/**
 * CSV/XLSX import & export for seller products. Images are not part of the
 * exported/imported columns — they are managed separately via the product form.
 */
class ProductImportExport
{
    public const HEADERS = [
        'sku',
        'name',
        'category',
        'product_type',
        'short_description',
        'description',
        'regular_price',
        'sale_price',
        'cost_price',
        'is_taxable',
        'stock',
        'min_stock',
        'track_inventory',
        'weight',
        'length',
        'width',
        'height',
        'requires_shipping',
        'status',
        'meta_title',
        'meta_description',
    ];

    /**
     * @return array<int, array<string, string|null>>
     */
    public static function rows(Collection $products): array
    {
        return $products->map(fn (Product $product) => [
            'sku' => $product->sku,
            'name' => $product->name,
            'category' => $product->category?->name,
            'product_type' => $product->product_type->value,
            'short_description' => $product->short_description,
            'description' => $product->description,
            'regular_price' => (string) $product->regular_price,
            'sale_price' => $product->sale_price !== null ? (string) $product->sale_price : null,
            'cost_price' => $product->cost_price !== null ? (string) $product->cost_price : null,
            'is_taxable' => $product->is_taxable ? '1' : '0',
            'stock' => (string) $product->stock,
            'min_stock' => (string) $product->min_stock,
            'track_inventory' => $product->track_inventory ? '1' : '0',
            'weight' => $product->weight !== null ? (string) $product->weight : null,
            'length' => $product->length !== null ? (string) $product->length : null,
            'width' => $product->width !== null ? (string) $product->width : null,
            'height' => $product->height !== null ? (string) $product->height : null,
            'requires_shipping' => $product->requires_shipping ? '1' : '0',
            'status' => $product->status->value,
            'meta_title' => $product->meta_title,
            'meta_description' => $product->meta_description,
        ])->values()->all();
    }

    public static function exportCsv(Collection $products): string
    {
        $rows = self::rows($products);

        $handle = fopen('php://temp', 'r+');
        fputcsv($handle, self::HEADERS);

        foreach ($rows as $row) {
            fputcsv($handle, array_map(fn ($value) => $value ?? '', $row));
        }

        rewind($handle);
        $csv = stream_get_contents($handle);
        fclose($handle);

        return $csv;
    }

    public static function exportXlsx(Collection $products): string
    {
        $rows = self::rows($products);

        $spreadsheet = new Spreadsheet;
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->fromArray(self::HEADERS, null, 'A1');

        foreach ($rows as $index => $row) {
            $sheet->fromArray(array_values($row), null, 'A'.($index + 2));
        }

        $writer = IOFactory::createWriter($spreadsheet, 'Xlsx');

        $tmpPath = tempnam(sys_get_temp_dir(), 'products_export_');
        $writer->save($tmpPath);
        $contents = file_get_contents($tmpPath);
        unlink($tmpPath);

        return $contents;
    }

    /**
     * Parse and import an uploaded CSV or XLSX file into the given store.
     *
     * @return array{imported: int, skipped: array<int, array{row: int, reason: string}>}
     */
    public static function import(Store $store, UploadedFile $file, ProductService $productService): array
    {
        $extension = strtolower($file->getClientOriginalExtension());

        $rows = $extension === 'csv' || $extension === 'txt'
            ? self::readCsv($file)
            : self::readXlsx($file);

        $imported = 0;
        $skipped = [];

        foreach ($rows as $index => $row) {
            $rowNumber = $index + 2; // account for header + 1-indexing

            if (count(array_filter($row, fn ($v) => $v !== null && $v !== '')) === 0) {
                continue; // skip blank rows silently
            }

            $data = array_combine(self::HEADERS, array_pad(array_slice($row, 0, count(self::HEADERS)), count(self::HEADERS), null));

            $name = trim((string) ($data['name'] ?? ''));
            if ($name === '') {
                $skipped[] = ['row' => $rowNumber, 'reason' => 'Missing name.'];

                continue;
            }

            if (! is_numeric($data['regular_price'] ?? null)) {
                $skipped[] = ['row' => $rowNumber, 'reason' => 'Missing or invalid regular_price.'];

                continue;
            }

            $productType = ProductType::tryFrom((string) ($data['product_type'] ?? 'physical')) ?? ProductType::PHYSICAL;
            $status = ProductStatus::tryFrom((string) ($data['status'] ?? 'draft')) ?? ProductStatus::DRAFT;

            $categoryId = null;
            $categoryName = trim((string) ($data['category'] ?? ''));
            if ($categoryName !== '') {
                $categoryId = Category::query()->where('name', $categoryName)->value('id');

                if ($categoryId === null) {
                    $skipped[] = ['row' => $rowNumber, 'reason' => "Unknown category: {$categoryName}."];

                    continue;
                }
            }

            $sku = trim((string) ($data['sku'] ?? '')) ?: null;
            if ($sku !== null && $store->products()->where('sku', $sku)->exists()) {
                $skipped[] = ['row' => $rowNumber, 'reason' => "Duplicate sku: {$sku}."];

                continue;
            }

            $productService->create($store, [
                'sku' => $sku,
                'name' => $name,
                'category_id' => $categoryId,
                'product_type' => $productType->value,
                'short_description' => trim((string) ($data['short_description'] ?? '')) ?: null,
                'description' => trim((string) ($data['description'] ?? '')) ?: null,
                'regular_price' => (float) $data['regular_price'],
                'sale_price' => is_numeric($data['sale_price'] ?? null) ? (float) $data['sale_price'] : null,
                'cost_price' => is_numeric($data['cost_price'] ?? null) ? (float) $data['cost_price'] : null,
                'is_taxable' => self::toBool($data['is_taxable'] ?? null),
                'stock' => is_numeric($data['stock'] ?? null) ? (int) $data['stock'] : 0,
                'min_stock' => is_numeric($data['min_stock'] ?? null) ? (int) $data['min_stock'] : 0,
                'track_inventory' => self::toBool($data['track_inventory'] ?? null, true),
                'weight' => is_numeric($data['weight'] ?? null) ? (float) $data['weight'] : null,
                'length' => is_numeric($data['length'] ?? null) ? (float) $data['length'] : null,
                'width' => is_numeric($data['width'] ?? null) ? (float) $data['width'] : null,
                'height' => is_numeric($data['height'] ?? null) ? (float) $data['height'] : null,
                'requires_shipping' => self::toBool($data['requires_shipping'] ?? null, true),
                'status' => $status->value,
                'meta_title' => trim((string) ($data['meta_title'] ?? '')) ?: null,
                'meta_description' => trim((string) ($data['meta_description'] ?? '')) ?: null,
            ]);

            $imported++;
        }

        return ['imported' => $imported, 'skipped' => $skipped];
    }

    /**
     * @return array<int, array<int, string|null>>
     */
    private static function readCsv(UploadedFile $file): array
    {
        $lines = array_map('str_getcsv', file($file->getRealPath()));
        array_shift($lines); // header row

        return $lines;
    }

    /**
     * @return array<int, array<int, string|null>>
     */
    private static function readXlsx(UploadedFile $file): array
    {
        $spreadsheet = IOFactory::load($file->getRealPath());
        $sheet = $spreadsheet->getActiveSheet();
        $rows = $sheet->toArray(null, true, true, false);

        array_shift($rows); // header row

        return $rows;
    }

    private static function toBool(mixed $value, bool $default = false): bool
    {
        if ($value === null || $value === '') {
            return $default;
        }

        return in_array(strtolower(trim((string) $value)), ['1', 'true', 'yes', 'ya'], true);
    }
}
