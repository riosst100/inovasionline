<?php

namespace Database\Seeders;

use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Laravolt\Indonesia\Seeds\CsvtoArray;

class IndonesiaRegionSeeder extends Seeder
{
    /**
     * Only DKI Jakarta and Jawa Tengah are supported for now.
     *
     * @see \App\Http\Controllers\Api\V1\RegionController
     */
    private const ACTIVE_PROVINCE_CODES = ['31', '33'];

    /**
     * Within Jawa Tengah (33), only Kabupaten Brebes is supported for now.
     */
    private const ACTIVE_CITY_CODES_BY_PROVINCE = [
        '33' => ['3329'],
    ];

    public function run(): void
    {
        $now = Carbon::now();
        $csv = new CsvtoArray();
        $prefix = config('laravolt.indonesia.table_prefix');
        $csvPath = base_path('vendor/laravolt/indonesia/resources/csv');

        $provinces = $this->filterByCode(
            $csv->csv_to_array($csvPath.'/provinces.csv', ['code', 'name', 'lat', 'long']),
            self::ACTIVE_PROVINCE_CODES
        );
        $this->insertWithMeta(DB::table($prefix.'provinces'), $provinces, $now);

        $cities = array_filter(
            $csv->csv_to_array($csvPath.'/cities.csv', ['code', 'province_code', 'name', 'lat', 'long']),
            fn (array $row) => in_array($row['province_code'], self::ACTIVE_PROVINCE_CODES, true)
                && (! isset(self::ACTIVE_CITY_CODES_BY_PROVINCE[$row['province_code']])
                    || in_array($row['code'], self::ACTIVE_CITY_CODES_BY_PROVINCE[$row['province_code']], true))
        );
        $this->insertWithMeta(DB::table($prefix.'cities'), $cities, $now);
        $cityCodes = array_column($cities, 'code');

        $districts = array_filter(
            $csv->csv_to_array($csvPath.'/districts.csv', ['code', 'city_code', 'name', 'lat', 'long']),
            fn (array $row) => in_array($row['city_code'], $cityCodes, true)
        );
        $this->insertWithMeta(DB::table($prefix.'districts'), $districts, $now);
        $districtCodes = array_column($districts, 'code');

        $villages = [];
        foreach (self::ACTIVE_PROVINCE_CODES as $provinceCode) {
            $file = $csvPath."/villages/{$provinceCode}.csv";
            if (! file_exists($file)) {
                continue;
            }

            $rows = $csv->csv_to_array($file, ['code', 'district_code', 'name', 'lat', 'long', 'pos']);
            $villages = array_merge(
                $villages,
                array_filter($rows, fn (array $row) => in_array($row['district_code'], $districtCodes, true))
            );
        }
        $this->insertWithMeta(DB::table($prefix.'villages'), $villages, $now, ['pos']);
    }

    /**
     * @param  array<string>  $codes
     * @return array<int, array<string, string>>
     */
    private function filterByCode(array $rows, array $codes): array
    {
        return array_filter($rows, fn (array $row) => in_array($row['code'], $codes, true));
    }

    /**
     * @param  array<int, array<string, string>>  $rows
     * @param  array<string>  $extraMetaKeys
     */
    private function insertWithMeta($table, array $rows, Carbon $now, array $extraMetaKeys = []): void
    {
        if ($rows === []) {
            return;
        }

        $metaKeys = array_merge(['lat', 'long'], $extraMetaKeys);

        $data = array_map(function (array $row) use ($now, $metaKeys) {
            $row['meta'] = json_encode(array_intersect_key($row, array_flip($metaKeys)));
            foreach ($metaKeys as $key) {
                unset($row[$key]);
            }

            return $row + ['created_at' => $now, 'updated_at' => $now];
        }, array_values($rows));

        foreach (array_chunk($data, 50) as $chunk) {
            $table->insertOrIgnore($chunk);
        }
    }
}
