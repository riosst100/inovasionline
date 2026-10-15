<?php

namespace App\Services;

use App\Http\Controllers\Api\V1\RegionController;
use App\Models\ServiceCity;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Turns coordinates into the nearest served village, and village codes into a
 * readable address label.
 */
class RegionLocator
{
    /** Reject locations farther than this from any served village. */
    private const MAX_DISTANCE_KM = 30;

    /**
     * Nearest village (straight-line distance) within the served cities, or
     * null when none is within MAX_DISTANCE_KM.
     *
     * @return array{province_code: string, city_code: string, district_code: string, village_code: string, label: string}|null
     */
    public function nearest(float $lat, float $lng): ?array
    {
        $cityCodes = ServiceCity::activeCodes() ?? RegionController::defaultCityCodes();

        $rows = DB::table('indonesia_villages as v')
            ->join('indonesia_districts as d', 'd.code', '=', 'v.district_code')
            ->join('indonesia_cities as c', 'c.code', '=', 'd.city_code')
            ->whereIn('c.code', $cityCodes)
            ->get([
                'v.code as village_code',
                'v.name as village_name',
                'v.meta',
                'd.code as district_code',
                'd.name as district_name',
                'c.code as city_code',
                'c.name as city_name',
                'c.province_code',
            ]);

        $best = null;
        $bestDistance = self::MAX_DISTANCE_KM;

        foreach ($rows as $row) {
            $meta = json_decode($row->meta ?? '', true);
            if (! is_array($meta) || ! is_numeric($meta['lat'] ?? null) || ! is_numeric($meta['long'] ?? null)) {
                continue;
            }

            $distance = $this->haversineKm($lat, $lng, (float) $meta['lat'], (float) $meta['long']);
            if ($distance < $bestDistance) {
                $bestDistance = $distance;
                $best = [
                    'province_code' => trim($row->province_code),
                    'city_code' => trim($row->city_code),
                    'district_code' => trim($row->district_code),
                    'village_code' => trim($row->village_code),
                    'label' => $this->label($row->village_name, $row->district_name, $row->city_name),
                ];
            }
        }

        return $best;
    }

    /** "Village, District, City", or null when the village is unknown. */
    public function labelForVillage(?string $villageCode): ?string
    {
        if ($villageCode === null) {
            return null;
        }

        $row = DB::table('indonesia_villages as v')
            ->join('indonesia_districts as d', 'd.code', '=', 'v.district_code')
            ->join('indonesia_cities as c', 'c.code', '=', 'd.city_code')
            ->where('v.code', $villageCode)
            ->first(['v.name as village_name', 'd.name as district_name', 'c.name as city_name']);

        return $row ? $this->label($row->village_name, $row->district_name, $row->city_name) : null;
    }

    private function label(string $village, string $district, string $city): string
    {
        return collect([$village, $district, $city])
            ->map(fn (string $name) => Str::title(Str::lower(trim($name))))
            ->implode(', ');
    }

    private function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return 6371 * 2 * asin(min(1, sqrt($a)));
    }
}
