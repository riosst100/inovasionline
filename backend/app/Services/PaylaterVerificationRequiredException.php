<?php

namespace App\Services;

use RuntimeException;

/** Raised at checkout when a first-time Paylater order is placed before face verification. */
class PaylaterVerificationRequiredException extends RuntimeException
{
    public const CODE = 'PAYLATER_VERIFICATION_REQUIRED';

    public function __construct()
    {
        parent::__construct('Verifikasi wajah diperlukan untuk pertama kali menggunakan Paylater.');
    }
}
