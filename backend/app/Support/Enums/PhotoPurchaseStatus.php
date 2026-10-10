<?php

namespace App\Support\Enums;

enum PhotoPurchaseStatus: string
{
    case PAID = 'paid';
    case CANCELLED = 'cancelled';
}
