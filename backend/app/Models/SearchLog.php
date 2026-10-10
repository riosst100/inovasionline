<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class SearchLog extends Model
{
    protected $fillable = [
        'keyword',
        'search_count',
        'last_searched_at',
    ];

    protected function casts(): array
    {
        return [
            'search_count' => 'integer',
            'last_searched_at' => 'datetime',
        ];
    }

    public static function record(string $keyword): void
    {
        $normalized = mb_strtolower(trim($keyword));

        if ($normalized === '') {
            return;
        }

        $now = now();

        DB::statement(
            'insert into search_logs (keyword, search_count, last_searched_at, created_at, updated_at)
             values (?, 1, ?, ?, ?)
             on conflict (keyword) do update set
                search_count = search_logs.search_count + 1,
                last_searched_at = excluded.last_searched_at,
                updated_at = excluded.updated_at',
            [$normalized, $now, $now, $now]
        );
    }
}
