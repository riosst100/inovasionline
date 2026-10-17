<?php

namespace App\Support\Enums;

enum ShippingMethodType: string
{
    case STORE_PICKUP = 'store_pickup';
    case STORE_DELIVERY = 'store_delivery';
    case PLATFORM_DELIVERY = 'platform_delivery';
    case COURIER = 'courier';
    case IO_EXPRESS = 'io_express';
    case IO_SAME_DAY = 'io_same_day';
    /** Added by an admin (e.g. "Jastip Maysa"). */
    case CUSTOM = 'custom';
}
