<?php

namespace App\Services;

use RuntimeException;

/** The bonus needs a fully watched rewarded ad that AdMob has not confirmed (yet). */
class AdViewRequiredException extends RuntimeException {}
