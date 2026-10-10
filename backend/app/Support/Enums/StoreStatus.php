<?php

namespace App\Support\Enums;

enum StoreStatus: string
{
    case OPEN = 'open';
    case CLOSED = 'closed';
    case TEMPORARILY_CLOSED = 'temporarily_closed';
}
