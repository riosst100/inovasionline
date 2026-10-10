<?php

namespace App\Support\Enums;

enum ShippingMethodType: string
{
    case STORE_PICKUP = 'store_pickup';
    case SELLER_DELIVERY = 'seller_delivery';
    case PLATFORM_DELIVERY = 'platform_delivery';
    case COURIER = 'courier';
}
