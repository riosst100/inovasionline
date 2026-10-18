<?php

namespace App\Support\Enums;

enum OrderStatus: string
{
    case PENDING = 'pending';
    case PROCESSING = 'processing';
    case READY = 'ready';
    case ON_DELIVERY = 'on_delivery';
    case COMPLETED = 'completed';
    case CANCELLED = 'cancelled';
}
