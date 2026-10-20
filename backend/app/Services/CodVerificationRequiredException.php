<?php

namespace App\Services;

use RuntimeException;

/** Raised at checkout when a COD order is placed before the customer's face verification. */
class CodVerificationRequiredException extends RuntimeException
{
    public const CODE = 'COD_VERIFICATION_REQUIRED';

    public function __construct()
    {
        parent::__construct('Verifikasi wajah diperlukan untuk pembayaran COD.');
    }
}
