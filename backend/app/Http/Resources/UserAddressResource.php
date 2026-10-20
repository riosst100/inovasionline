<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\DB;

class UserAddressResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // Names alongside the codes, so the app can show the address and
        // prefill its region dropdowns without looking each level up.
        $names = DB::table('indonesia_villages as v')
            ->join('indonesia_districts as d', 'd.code', '=', 'v.district_code')
            ->join('indonesia_cities as c', 'c.code', '=', 'd.city_code')
            ->join('indonesia_provinces as p', 'p.code', '=', 'c.province_code')
            ->where('v.code', $this->village_code)
            ->first(['p.name as province', 'c.name as city', 'd.name as district', 'v.name as village']);

        $region = fn (string $code, ?string $name) => ['code' => $code, 'name' => $name ?? $code];

        return [
            'id' => $this->id,
            'label' => $this->label,
            'recipient_name' => $this->recipient_name,
            'recipient_phone' => $this->recipient_phone,
            'province' => $region($this->province_code, $names?->province),
            'city' => $region($this->city_code, $names?->city),
            'district' => $region($this->district_code, $names?->district),
            'village' => $region($this->village_code, $names?->village),
            'address_detail' => $this->address_detail,
            'last_used_at' => $this->last_used_at,
            'created_at' => $this->created_at,
        ];
    }
}
