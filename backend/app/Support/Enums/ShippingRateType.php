<?php

namespace App\Support\Enums;

enum ShippingRateType: string
{
    case FLAT = 'flat';
    case TABLE = 'table';
}
