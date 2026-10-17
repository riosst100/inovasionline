<?php

namespace App\Support\DataTransfer;

use RuntimeException;

/** Thrown by a TransferHandler to reject a single import row with a user-facing reason. */
class RowSkippedException extends RuntimeException {}
