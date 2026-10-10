<?php

namespace App\Support\Enums;

enum OrderStatus: string
{
    case PENDING = 'pending';
    case ACCEPTED = 'accepted';
    case PROCESSING = 'processing';
    case READY = 'ready';
    case COMPLETED = 'completed';
    case CANCELLED = 'cancelled';
}
