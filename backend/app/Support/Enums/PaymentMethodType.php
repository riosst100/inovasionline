<?php

namespace App\Support\Enums;

enum PaymentMethodType: string
{
    case CASH = 'cash';
    case BANK_TRANSFER = 'bank_transfer';
    case EWALLET = 'ewallet';
    case QRIS = 'qris';
    case CASH_ON_DELIVERY = 'cash_on_delivery';
    case PAYMENT_GATEWAY = 'payment_gateway';
    case WALLET = 'wallet';
    case PAYLATER = 'paylater';

    /** Admin-owned bank and e-wallet accounts used for manual checkout and manual top-up transfers. */
    public const MANUAL_ACCOUNT_TYPES = [
        self::BANK_TRANSFER->value,
        self::EWALLET->value,
    ];
}
