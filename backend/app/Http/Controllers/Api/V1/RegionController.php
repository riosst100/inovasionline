<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\RegionResource;
use App\Models\ServiceCity;
use App\Services\RegionLocator;
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
     * Built-in defaults, used until an admin configures Pengaturan > Cakupan Kota:
     * all of DKI Jakarta (31) plus Kabupaten Brebes (3329).
     *
     * @return list<string>
     */
    public static function defaultCityCodes(): array
    {
        return City::query()
            ->where('province_code', '31')
            ->orWhere('code', '3329')
            ->pluck('code')
            ->map(fn ($c) => trim($c))
            ->all();
    }

    /** @return list<string> */
    private function activeCityCodes(): array
    {
        return ServiceCity::activeCodes() ?? self::defaultCityCodes();
    }

    /**
     * Nearest served village to the given coordinates, so the app can default
     * a delivery address (also for guests, who have no account to save it on).
     */
    public function nearest(Request $request, RegionLocator $locator): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $village = $locator->nearest((float) $data['latitude'], (float) $data['longitude']);

        if ($village === null) {
            return ApiResponse::error('Lokasi Anda berada di luar area layanan.', [], 422);
        }

        return ApiResponse::success($village, 'Nearest village retrieved successfully.');
    }

    public function provinces(): JsonResponse
    {
        $provinceCodes = City::query()
            ->whereIn('code', $this->activeCityCodes())
            ->pluck('province_code')
            ->map(fn ($c) => trim($c))
            ->unique();

        $provinces = Province::query()
            ->whereIn('code', $provinceCodes)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($provinces), 'Provinces retrieved successfully.')
            ->header('Cache-Control', 'public, max-age=3600');
    }

    public function cities(Request $request, string $provinceCode): JsonResponse
    {
        $cities = City::query()
            ->where('province_code', $provinceCode)
            ->whereIn('code', $this->activeCityCodes())
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($cities), 'Cities retrieved successfully.')
            ->header('Cache-Control', 'public, max-age=3600');
    }

    public function districts(Request $request, string $cityCode): JsonResponse
    {
        $districts = District::query()
            ->where('city_code', $cityCode)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($districts), 'Districts retrieved successfully.')
            ->header('Cache-Control', 'public, max-age=3600');
    }

    public function villages(Request $request, string $districtCode): JsonResponse
    {
        $villages = Village::query()
            ->where('district_code', $districtCode)
            ->orderBy('name')
            ->get();

        return ApiResponse::success(RegionResource::collection($villages), 'Villages retrieved successfully.')
            ->header('Cache-Control', 'public, max-age=3600');
    }
}
