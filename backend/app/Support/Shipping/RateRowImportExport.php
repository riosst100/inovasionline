<?php

namespace App\Support\Shipping;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Village;

/**
 * Shared CSV import/export + upsert logic for shipping-method rate rows and
 * shipping-rate-template rows — both tables have the identical shape
 * (district_code, village_code, fee) scoped to a different parent FK.
 */
class RateRowImportExport
{
    /**
     * Upsert a single row keyed on (parent, district_code, village_code).
     */
    public static function upsert(HasMany $relation, ?string $districtCode, ?string $villageCode, float $fee)
    {
        if ($villageCode !== null && $districtCode === null) {
            $districtCode = Village::query()->where('code', $villageCode)->value('district_code');
        }

        $existing = $relation->clone()
            ->where('district_code', $districtCode)
            ->where('village_code', $villageCode)
            ->first();

        if ($existing) {
            $existing->update(['fee' => $fee]);

            return $existing;
        }

        return $relation->create([
            'district_code' => $districtCode,
            'village_code' => $villageCode,
            'fee' => $fee,
        ]);
    }

    /**
     * Resolve district/village names for a collection of rows in one batched
     * query each, avoiding N+1s, and attach them as `district_name`/`village_name`.
     */
    public static function withNames(iterable $rows): iterable
    {
        $rows = collect($rows);

        $districtCodes = $rows->pluck('district_code')->filter()->unique()->values();
        $villageCodes = $rows->pluck('village_code')->filter()->unique()->values();

        $districtNames = District::query()->whereIn('code', $districtCodes)->pluck('name', 'code');
        $villageNames = Village::query()->whereIn('code', $villageCodes)->pluck('name', 'code');

        return $rows->each(function ($row) use ($districtNames, $villageNames) {
            $row->district_name = $row->district_code ? ($districtNames[$row->district_code] ?? null) : null;
            $row->village_name = $row->village_code ? ($villageNames[$row->village_code] ?? null) : null;
        });
    }

    /**
     * @return array{0: string, 1: array<int, array{row: int, reason: string}>}
     *               CSV content for streamDownload, keyed by column header.
     */
    public static function exportCsv(iterable $rows): string
    {
        $rows = self::withNames($rows);

        $handle = fopen('php://temp', 'r+');
        fputcsv($handle, ['district_code', 'district_name', 'village_code', 'village_name', 'fee']);

        foreach ($rows as $row) {
            fputcsv($handle, [
                $row->district_code,
                $row->district_name,
                $row->village_code,
                $row->village_name,
                $row->fee,
            ]);
        }

        rewind($handle);
        $csv = stream_get_contents($handle);
        fclose($handle);

        return $csv;
    }

    /**
     * Parse and upsert an uploaded CSV into the given relation.
     *
     * @return array{imported: int, skipped: array<int, array{row: int, reason: string}>}
     */
    public static function importCsv(HasMany $relation, UploadedFile $file): array
    {
        $lines = array_map('str_getcsv', file($file->getRealPath()));
        array_shift($lines); // header row

        $imported = 0;
        $skipped = [];

        DB::transaction(function () use ($relation, $lines, &$imported, &$skipped) {
            foreach ($lines as $index => $line) {
                $rowNumber = $index + 2; // account for header + 1-indexing

                if (count(array_filter($line, fn ($v) => $v !== null && $v !== '')) === 0) {
                    continue; // skip blank lines silently
                }

                [$districtCode, , $villageCode, , $fee] = array_pad($line, 5, null);
                $districtCode = $districtCode !== '' ? $districtCode : null;
                $villageCode = $villageCode !== '' ? $villageCode : null;

                if ($districtCode === null && $villageCode === null) {
                    $skipped[] = ['row' => $rowNumber, 'reason' => 'Missing district_code and village_code.'];

                    continue;
                }

                if (! is_numeric($fee) || (float) $fee < 0) {
                    $skipped[] = ['row' => $rowNumber, 'reason' => 'Invalid fee value.'];

                    continue;
                }

                if ($districtCode !== null && ! District::query()->where('code', $districtCode)->exists()) {
                    $skipped[] = ['row' => $rowNumber, 'reason' => "Unknown district_code: {$districtCode}."];

                    continue;
                }

                if ($villageCode !== null && ! Village::query()->where('code', $villageCode)->exists()) {
                    $skipped[] = ['row' => $rowNumber, 'reason' => "Unknown village_code: {$villageCode}."];

                    continue;
                }

                self::upsert($relation, $districtCode, $villageCode, (float) $fee);
                $imported++;
            }
        });

        return ['imported' => $imported, 'skipped' => $skipped];
    }
}
