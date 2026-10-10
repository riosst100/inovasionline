<?php

namespace App\Services;

use App\Models\ShippingMethod;
use App\Support\Enums\ShippingRateType;

class ShippingRateResolver
{
    public function resolveFee(ShippingMethod $method, string $districtCode, ?string $villageCode): ?float
    {
        if ($method->rate_type === ShippingRateType::FLAT) {
            return (float) $method->base_fee;
        }

        if ($villageCode !== null) {
            $row = $method->rates()->where('village_code', $villageCode)->first();

            if ($row) {
                return (float) $row->fee;
            }
        }

        $row = $method->rates()->where('district_code', $districtCode)->whereNull('village_code')->first();

        return $row ? (float) $row->fee : null;
    }
}
