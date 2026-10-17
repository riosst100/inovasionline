<?php

namespace App\Support\DataTransfer;

use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use RuntimeException;

/**
 * Format-agnostic CSV/XLSX reading and writing for data transfers.
 */
class SpreadsheetFile
{
    public const FORMATS = ['csv', 'xlsx'];

    /**
     * Read a file into rows keyed by the original (1-based) file row number,
     * each row keyed by its normalized header. Blank rows are dropped.
     *
     * @return array<int, array<string, string|null>>
     */
    public static function read(string $path, string $format): array
    {
        $raw = $format === 'csv' ? self::readCsv($path) : self::readXlsx($path);

        if ($raw === []) {
            return [];
        }

        $headers = array_map(self::normalizeHeader(...), array_shift($raw));
        $rows = [];

        foreach ($raw as $index => $values) {
            $values = array_map(fn ($v) => $v === null ? null : trim((string) $v), $values);

            if (count(array_filter($values, fn ($v) => $v !== null && $v !== '')) === 0) {
                continue;
            }

            $row = [];
            foreach ($headers as $i => $header) {
                if ($header !== '') {
                    $value = $values[$i] ?? null;
                    $row[$header] = $value === '' ? null : $value;
                }
            }

            $rows[$index + 2] = $row; // +1 header row, +1 for 1-based numbering
        }

        return $rows;
    }

    /**
     * Write rows (each keyed by header) to the given path. Rows may be a
     * generator so callers can report progress while writing.
     *
     * @param  array<int, string>  $headers
     * @param  iterable<array<string, mixed>>  $rows
     */
    public static function write(string $path, string $format, array $headers, iterable $rows): void
    {
        $format === 'csv'
            ? self::writeCsv($path, $headers, $rows)
            : self::writeXlsx($path, $headers, $rows);
    }

    public static function mimeType(string $format): string
    {
        return $format === 'csv'
            ? 'text/csv'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    private static function normalizeHeader(mixed $header): string
    {
        return (string) preg_replace('/\s+/', '_', strtolower(trim((string) $header)));
    }

    /** @return array<int, array<int, string|null>> */
    private static function readCsv(string $path): array
    {
        $handle = fopen($path, 'r') ?: throw new RuntimeException('File tidak dapat dibaca.');

        $first = (string) fgets($handle);
        // Excel with an Indonesian locale saves CSV with ";".
        $delimiter = substr_count($first, ';') > substr_count($first, ',') ? ';' : ',';
        rewind($handle);

        $bom = fread($handle, 3);
        if ($bom !== "\xEF\xBB\xBF") {
            rewind($handle);
        }

        $rows = [];
        while (($line = fgetcsv($handle, null, $delimiter, '"', '')) !== false) {
            $rows[] = $line;
        }
        fclose($handle);

        return $rows;
    }

    /** @return array<int, array<int, string|null>> */
    private static function readXlsx(string $path): array
    {
        $reader = IOFactory::createReader('Xlsx');
        $reader->setReadDataOnly(true);

        try {
            $spreadsheet = $reader->load($path);
        } catch (\Throwable) {
            throw new RuntimeException('File XLSX tidak valid atau rusak.');
        }

        $rows = $spreadsheet->getActiveSheet()->toArray(null, true, false, false);
        $spreadsheet->disconnectWorksheets();

        return $rows;
    }

    /**
     * @param  array<int, string>  $headers
     * @param  iterable<array<string, mixed>>  $rows
     */
    private static function writeCsv(string $path, array $headers, iterable $rows): void
    {
        $handle = fopen($path, 'w') ?: throw new RuntimeException('File tidak dapat ditulis.');
        fwrite($handle, "\xEF\xBB\xBF"); // BOM so Excel opens UTF-8 correctly
        fputcsv($handle, $headers, ',', '"', '');

        foreach ($rows as $row) {
            fputcsv($handle, array_map(fn ($h) => $row[$h] ?? '', $headers), ',', '"', '');
        }

        fclose($handle);
    }

    /**
     * @param  array<int, string>  $headers
     * @param  iterable<array<string, mixed>>  $rows
     */
    private static function writeXlsx(string $path, array $headers, iterable $rows): void
    {
        $spreadsheet = new Spreadsheet;
        $sheet = $spreadsheet->getActiveSheet();

        foreach ($headers as $i => $header) {
            $sheet->setCellValue([$i + 1, 1], $header);
        }
        $sheet->getStyle('A1:'.Coordinate::stringFromColumnIndex(count($headers)).'1')->getFont()->setBold(true);

        $line = 2;
        foreach ($rows as $row) {
            foreach ($headers as $i => $header) {
                $value = $row[$header] ?? null;
                if ($value === null || $value === '') {
                    continue;
                }
                // Strings are written explicitly so values like "=..." never become formulas.
                is_int($value) || is_float($value)
                    ? $sheet->setCellValue([$i + 1, $line], $value)
                    : $sheet->setCellValueExplicit([$i + 1, $line], (string) $value, DataType::TYPE_STRING);
            }
            $line++;
        }

        foreach (range(1, count($headers)) as $column) {
            $sheet->getColumnDimensionByColumn($column)->setAutoSize(true);
        }

        IOFactory::createWriter($spreadsheet, 'Xlsx')->save($path);
        $spreadsheet->disconnectWorksheets();
    }
}
