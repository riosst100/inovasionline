<?php

namespace App\Support\Enums;

enum UserRole: string
{
    case CUSTOMER = 'customer';
    case SELLER_OWNER = 'seller_owner';
    case SELLER_STAFF = 'seller_staff';
    case PLATFORM_ADMIN = 'platform_admin';
    case PHOTOGRAPHER = 'photographer';
}
