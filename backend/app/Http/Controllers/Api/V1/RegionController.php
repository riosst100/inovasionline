<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\RegionResource;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravolt\Indonesia\Models\City;
use Laravolt\Indonesia\Models\District;
use Laravolt\Indonesia\Models\Province;
use Laravolt\Indonesia\Models\Village;

class RegionController extends Controller
{
    /**
     * Only DKI Jakarta and Jawa Tengah are supported for now.
     *
     * @var list<string>
     */
    private const ACTIVE_PROVINCE_CODES = ['31', '33'];

    /**
     * Within Jawa Tengah (33), only Kabupaten Brebes is supported for now.
     *
     * @var list<string>
     */
    private const ACTIVE_CITY_CODES_BY_PROVINCE = [
        '33' => ['3329'],
    ];

    public function provinces(): JsonResponse
    {
        $provinces = Province::query()
            ->whereIn('code', self::ACTIVE_PROVINCE_CODES)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($provinces), 'Provinces retrieved successfully.');
    }

    public function cities(Request $request, string $provinceCode): JsonResponse
    {
        if (! in_array($provinceCode, self::ACTIVE_PROVINCE_CODES, true)) {
            return ApiResponse::success([], 'Cities retrieved successfully.');
        }

        $cities = City::query()
            ->where('province_code', $provinceCode)
            ->when(
                isset(self::ACTIVE_CITY_CODES_BY_PROVINCE[$provinceCode]),
                fn ($query) => $query->whereIn('code', self::ACTIVE_CITY_CODES_BY_PROVINCE[$provinceCode])
            )
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($cities), 'Cities retrieved successfully.');
    }

    public function districts(Request $request, string $cityCode): JsonResponse
    {
        $districts = District::query()
            ->where('city_code', $cityCode)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($districts), 'Districts retrieved successfully.');
    }

    public function villages(Request $request, string $districtCode): JsonResponse
    {
        $villages = Village::query()
            ->where('district_code', $districtCode)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($villages), 'Villages retrieved successfully.');
    }
}
