<?php

namespace App\Support\Enums;

enum UserRole: string
{
    case CUSTOMER = 'customer';
    case PLATFORM_ADMIN = 'platform_admin';
    case PHOTOGRAPHER = 'photographer';
}
