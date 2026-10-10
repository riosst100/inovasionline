<?php

namespace App\Support\Enums;

enum PromotionType: string
{
    case PERCENTAGE_DISCOUNT = 'percentage_discount';
    case FIXED_DISCOUNT = 'fixed_discount';
    case FREE_SHIPPING = 'free_shipping';
    case BUY_ONE_GET_ONE = 'buy_one_get_one';
}
