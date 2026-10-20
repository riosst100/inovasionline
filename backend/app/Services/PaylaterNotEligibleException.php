<?php

namespace App\Services;

use RuntimeException;

/** Raised at checkout when the customer has not completed enough transactions for Paylater. */
class PaylaterNotEligibleException extends RuntimeException
{
    public const CODE = 'PAYLATER_NOT_ELIGIBLE';
}
