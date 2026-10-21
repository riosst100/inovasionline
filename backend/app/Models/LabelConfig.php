<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LabelConfig extends Model
{
    public const COLORS = ['slate', 'emerald', 'amber', 'violet', 'sky', 'green', 'red', 'rose', 'orange', 'blue'];

    protected $fillable = ['group', 'key', 'label', 'color', 'sort_order'];
}
