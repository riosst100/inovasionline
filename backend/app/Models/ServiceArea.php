<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A district or village inside a served city that narrows the coverage down.
 * A city with no rows is served as a whole; once it has some, only those
 * districts (entirely) and villages are served.
 */
class ServiceArea extends Model
{
    public const DISTRICT = 'district';

    public const VILLAGE = 'village';

    protected $fillable = ['level', 'code', 'city_code', 'district_code'];

    /**
     * Restrictions per city code:
     * city => ['districts' => [code => true], 'villages' => [code => true]].
     *
     * @return array<string, array{districts: array<string, true>, villages: array<string, true>}>
     */
    public static function restrictions(): array
    {
        $map = [];

        foreach (static::query()->get(['level', 'code', 'city_code', 'district_code']) as $row) {
            $city = trim($row->city_code);
            $map[$city] ??= ['districts' => [], 'villages' => []];

            if ($row->level === self::DISTRICT) {
                $map[$city]['districts'][trim($row->code)] = true;
            } else {
                $map[$city]['villages'][trim($row->code)] = true;
            }
        }

        return $map;
    }

    /**
     * Whether a village is served, given the map from [restrictions()].
     *
     * @param  array<string, array{districts: array<string, true>, villages: array<string, true>}>  $restrictions
     */
    public static function allows(array $restrictions, string $cityCode, string $districtCode, string $villageCode): bool
    {
        $rule = $restrictions[trim($cityCode)] ?? null;

        return $rule === null
            || isset($rule['districts'][trim($districtCode)])
            || isset($rule['villages'][trim($villageCode)]);
    }
}
