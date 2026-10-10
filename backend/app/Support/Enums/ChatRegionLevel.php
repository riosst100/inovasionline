<?php

namespace App\Support\Enums;

enum ChatRegionLevel: string
{
    case PROVINCE = 'province';
    case CITY = 'city';
    case DISTRICT = 'district';
    case VILLAGE = 'village';
}
