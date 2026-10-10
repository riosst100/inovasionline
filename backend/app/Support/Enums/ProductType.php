<?php

namespace App\Support\Enums;

enum ProductType: string
{
    case PHYSICAL = 'physical';
    case FOOD = 'food';
    case SERVICE = 'service';
    case DIGITAL = 'digital';
}
