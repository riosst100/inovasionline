<?php

namespace App\Support\Enums;

enum PaymentMethodType: string
{
    case CASH = 'cash';
    case BANK_TRANSFER = 'bank_transfer';
    case QRIS = 'qris';
    case CASH_ON_DELIVERY = 'cash_on_delivery';
    case PAYMENT_GATEWAY = 'payment_gateway';
}
