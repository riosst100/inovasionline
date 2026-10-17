<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A queued CSV/XLSX import or export job and its progress. The resource it
 * targets is resolved through App\Support\DataTransfer\DataTransferRegistry.
 */
class DataTransfer extends Model
{
    use HasUlids;

    public const TYPE_IMPORT = 'import';

    public const TYPE_EXPORT = 'export';

    public const STATUS_PENDING = 'pending';

    public const STATUS_PROCESSING = 'processing';

    public const STATUS_COMPLETED = 'completed';

    public const STATUS_FAILED = 'failed';

    /** Row errors kept per transfer; the rest are only counted in failed_rows. */
    public const MAX_ROW_ERRORS = 500;

    protected $fillable = [
        'type',
        'resource',
        'format',
        'status',
        'file_name',
        'file_path',
        'filters',
        'total_rows',
        'processed_rows',
        'created_rows',
        'updated_rows',
        'failed_rows',
        'row_errors',
        'error_message',
        'admin_user_id',
        'started_at',
        'finished_at',
    ];

    protected function casts(): array
    {
        return [
            'filters' => 'array',
            'row_errors' => 'array',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
        ];
    }

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class);
    }

    public function isFinished(): bool
    {
        return in_array($this->status, [self::STATUS_COMPLETED, self::STATUS_FAILED], true);
    }

    public function markFailed(string $message): void
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'error_message' => mb_substr($message, 0, 2000),
            'finished_at' => now(),
        ]);
    }
}
