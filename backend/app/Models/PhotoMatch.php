<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Relations\Pivot;

class PhotoMatch extends Pivot
{
    use HasUlids;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $table = 'photo_matches';

    protected function casts(): array
    {
        return [
            'confidence_score' => 'decimal:4',
        ];
    }
}
