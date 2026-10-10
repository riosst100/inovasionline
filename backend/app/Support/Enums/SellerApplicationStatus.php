<?php

namespace App\Support\Enums;

enum SellerApplicationStatus: string
{
    case PENDING = 'pending';
    case APPROVED = 'approved';
    case REJECTED = 'rejected';
    case SUSPENDED = 'suspended';
}
