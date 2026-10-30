<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\RegionController;
use App\Http\Controllers\Controller;
use App\Models\ServiceArea;
use App\Models\ServiceCity;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravolt\Indonesia\Models\City;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Province;
use Laravolt\Indonesia\Models\Village;

class ServiceCityController extends Controller
{
    public function index(): JsonResponse
    {
        $cities = City::query()->orderBy('name')->get(['code', 'name', 'province_code'])
            ->groupBy(fn ($c) => trim($c->province_code));

        $provinces = Province::query()->orderBy('name')->get(['code', 'name'])
            ->map(fn ($p) => [
                'code' => trim($p->code),
                'name' => $p->name,
                'cities' => ($cities[trim($p->code)] ?? collect())
                    ->map(fn ($c) => ['code' => trim($c->code), 'name' => $c->name])
                    ->values()
                    ->all(),
            ])
            ->values()
            ->all();

        return ApiResponse::success([
            'selected' => ServiceCity::activeCodes() ?? RegionController::defaultCityCodes(),
            'areas' => ServiceArea::query()->get(['level', 'code', 'city_code', 'district_code'])
                ->map(fn ($a) => [
                    'level' => $a->level,
                    'code' => trim($a->code),
                    'city_code' => trim($a->city_code),
                    'district_code' => trim($a->district_code),
                ])
                ->values()
                ->all(),
            'provinces' => $provinces,
        ], 'Service cities retrieved successfully.');
    }

    /** Every district of a city, unfiltered: coverage is narrowed down from these. */
    public function districts(string $cityCode): JsonResponse
    {
        $districts = District::query()->where('city_code', $cityCode)->orderBy('name')->get(['code', 'name'])
            ->map(fn ($d) => ['code' => trim($d->code), 'name' => $d->name])
            ->values()
            ->all();

        return ApiResponse::success($districts, 'Districts retrieved successfully.');
    }

    public function villages(string $districtCode): JsonResponse
    {
        $villages = Village::query()->where('district_code', $districtCode)->orderBy('name')->get(['code', 'name'])
            ->map(fn ($v) => ['code' => trim($v->code), 'name' => $v->name])
            ->values()
            ->all();

        return ApiResponse::success($villages, 'Villages retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'cities' => ['required', 'array', 'min:1', 'max:600'],
            'cities.*' => ['string', 'distinct', 'exists:'.(new City)->getTable().',code'],
            'areas' => ['sometimes', 'array', 'max:20000'],
            'areas.*.level' => ['required', 'in:'.ServiceArea::DISTRICT.','.ServiceArea::VILLAGE],
            'areas.*.code' => ['required', 'string'],
        ], [
            'cities.required' => 'Pilih minimal satu kota.',
            'cities.min' => 'Pilih minimal satu kota.',
            'cities.*.exists' => 'Terdapat kota yang tidak valid.',
        ]);

        $cities = array_map('trim', $data['cities']);
        $areas = $this->resolveAreas($data['areas'] ?? [], $cities);

        DB::transaction(function () use ($data, $areas) {
            ServiceCity::query()->delete();
            ServiceArea::query()->delete();
            $now = now();
            ServiceCity::insert(array_map(
                fn ($c) => ['city_code' => trim($c), 'created_at' => $now, 'updated_at' => $now],
                $data['cities']
            ));
            if ($areas !== []) {
                ServiceArea::insert($areas);
            }
        });

        return ApiResponse::success(['selected' => ServiceCity::activeCodes()], 'Cakupan wilayah berhasil disimpan.');
    }

    /**
     * Fills in each area's city and district from the region tables and keeps
     * only those inside a selected city, so a stale pick cannot widen coverage.
     *
     * @param  list<array{level: string, code: string}>  $areas
     * @param  list<string>  $cities
     * @return list<array<string, mixed>>
     */
    private function resolveAreas(array $areas, array $cities): array
    {
        $areas = collect($areas);
        $districtCodes = $areas->where('level', ServiceArea::DISTRICT)->pluck('code')->map(fn ($c) => trim($c))->unique()->all();
        $villageCodes = $areas->where('level', ServiceArea::VILLAGE)->pluck('code')->map(fn ($c) => trim($c))->unique()->all();

        /** @var array<string, string> $districtCity district code => city code */
        $districtCity = District::query()->whereIn('code', $districtCodes)->get(['code', 'city_code'])
            ->mapWithKeys(fn ($d) => [trim($d->code) => trim($d->city_code)])
            ->all();

        $villages = Village::query()->whereIn('code', $villageCodes)->get(['code', 'district_code'])
            ->map(fn ($v) => ['code' => trim($v->code), 'district' => trim($v->district_code)]);

        $villageDistrictCity = District::query()
            ->whereIn('code', $villages->pluck('district')->unique()->all())
            ->get(['code', 'city_code'])
            ->mapWithKeys(fn ($d) => [trim($d->code) => trim($d->city_code)])
            ->all();

        $now = now();
        $rows = [];

        foreach ($districtCity as $code => $city) {
            if (in_array($city, $cities, true)) {
                $rows[] = ['level' => ServiceArea::DISTRICT, 'code' => $code, 'city_code' => $city, 'district_code' => $code, 'created_at' => $now, 'updated_at' => $now];
            }
        }

        foreach ($villages as $v) {
            $city = $villageDistrictCity[$v['district']] ?? null;
            // A village inside a fully selected district adds nothing.
            if ($city !== null && in_array($city, $cities, true) && ! isset($districtCity[$v['district']])) {
                $rows[] = ['level' => ServiceArea::VILLAGE, 'code' => $v['code'], 'city_code' => $city, 'district_code' => $v['district'], 'created_at' => $now, 'updated_at' => $now];
            }
        }

        return $rows;
    }
}
