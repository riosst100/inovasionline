<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\RegionController;
use App\Http\Controllers\Controller;
use App\Models\ServiceCity;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravolt\Indonesia\Models\City;
use Laravolt\Indonesia\Models\Province;

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
            'provinces' => $provinces,
        ], 'Service cities retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'cities' => ['required', 'array', 'min:1', 'max:600'],
            'cities.*' => ['string', 'distinct', 'exists:'.(new City)->getTable().',code'],
        ], [
            'cities.required' => 'Pilih minimal satu kota.',
            'cities.min' => 'Pilih minimal satu kota.',
            'cities.*.exists' => 'Terdapat kota yang tidak valid.',
        ]);

        DB::transaction(function () use ($data) {
            ServiceCity::query()->delete();
            $now = now();
            ServiceCity::insert(array_map(
                fn ($c) => ['city_code' => trim($c), 'created_at' => $now, 'updated_at' => $now],
                $data['cities']
            ));
        });

        return ApiResponse::success(['selected' => ServiceCity::activeCodes()], 'Cakupan kota berhasil disimpan.');
    }
}
