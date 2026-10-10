<?php

namespace App\Support\Enums;

enum UserVerificationStatus: string
{
    case PENDING = 'pending';
    case APPROVED = 'approved';
    case REJECTED = 'rejected';
}
