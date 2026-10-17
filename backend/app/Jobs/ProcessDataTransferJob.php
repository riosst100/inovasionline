<?php

namespace App\Jobs;

use App\Models\DataTransfer;
use App\Support\DataTransfer\DataTransferRegistry;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use App\Support\DataTransfer\SpreadsheetFile;
use App\Support\DataTransfer\TransferHandler;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * Runs a queued CSV/XLSX import or export for any resource registered in
 * DataTransferRegistry, writing progress back to the DataTransfer row.
 */
class ProcessDataTransferJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Imports are not idempotent row-by-row, so never retry automatically. */
    public int $tries = 1;

    public int $timeout = 1800;

    public function __construct(public readonly DataTransfer $transfer) {}

    public function handle(): void
    {
        $transfer = $this->transfer;
        $transfer->update([
            'status' => DataTransfer::STATUS_PROCESSING,
            'started_at' => now(),
        ]);

        $handler = DataTransferRegistry::handler($transfer->resource);

        $transfer->type === DataTransfer::TYPE_IMPORT
            ? $this->import($transfer, $handler)
            : $this->export($transfer, $handler);
    }

    public function failed(?Throwable $e): void
    {
        Log::error('Data transfer failed', ['id' => $this->transfer->id, 'error' => $e?->getMessage()]);

        $this->transfer->fresh()?->markFailed($e?->getMessage() ?: 'Proses gagal.');
    }

    private function import(DataTransfer $transfer, TransferHandler $handler): void
    {
        $rows = SpreadsheetFile::read(Storage::disk('local')->path($transfer->file_path), $transfer->format);

        if ($rows !== [] && array_intersect($handler->headers(), array_keys(reset($rows))) === []) {
            $transfer->markFailed('Header kolom tidak dikenali. Gunakan template: '.implode(', ', $handler->headers()));

            return;
        }

        $rows = $handler->prepareImport($rows);
        $transfer->update(['total_rows' => count($rows)]);

        $counts = ['processed_rows' => 0, 'created_rows' => 0, 'updated_rows' => 0, 'failed_rows' => 0];
        $errors = [];
        $step = max(1, intdiv(count($rows), 100));

        foreach ($rows as $rowNumber => $row) {
            try {
                // Each row is atomic; a bad row never rolls back the good ones.
                $result = DB::transaction(fn () => $handler->importRow($row));
                $counts[$result === ImportResult::CREATED ? 'created_rows' : 'updated_rows']++;
            } catch (RowSkippedException $e) {
                $this->recordError($counts, $errors, $rowNumber, $e->getMessage());
            } catch (Throwable $e) {
                Log::warning('Data transfer row failed', ['id' => $transfer->id, 'row' => $rowNumber, 'error' => $e->getMessage()]);
                $this->recordError($counts, $errors, $rowNumber, 'Gagal menyimpan baris: '.Str::limit($e->getMessage(), 200));
            }

            $counts['processed_rows']++;
            if ($counts['processed_rows'] % $step === 0) {
                $transfer->update([...$counts, 'row_errors' => $errors]);
            }
        }

        $transfer->update([
            ...$counts,
            'row_errors' => $errors,
            'status' => DataTransfer::STATUS_COMPLETED,
            'finished_at' => now(),
        ]);
    }

    private function export(DataTransfer $transfer, TransferHandler $handler): void
    {
        $query = $handler->exportQuery($transfer->filters ?? []);
        $total = (clone $query)->count();
        $transfer->update(['total_rows' => $total]);

        $path = "data-transfers/{$transfer->id}/{$transfer->file_name}";
        Storage::disk('local')->makeDirectory(dirname($path));

        $step = max(1, intdiv($total, 100));
        $rows = (function () use ($query, $handler, $transfer, $step) {
            $processed = 0;
            foreach ($query->lazy(500) as $model) {
                yield $handler->exportRow($model);

                if (++$processed % $step === 0) {
                    $transfer->update(['processed_rows' => $processed]);
                }
            }
        })();

        SpreadsheetFile::write(Storage::disk('local')->path($path), $transfer->format, $handler->headers(), $rows);

        $transfer->update([
            'file_path' => $path,
            'processed_rows' => $total,
            'created_rows' => $total,
            'status' => DataTransfer::STATUS_COMPLETED,
            'finished_at' => now(),
        ]);
    }

    /**
     * @param  array<string, int>  $counts
     * @param  array<int, array{row: int, message: string}>  $errors
     */
    private function recordError(array &$counts, array &$errors, int $row, string $message): void
    {
        $counts['failed_rows']++;
        if (count($errors) < DataTransfer::MAX_ROW_ERRORS) {
            $errors[] = ['row' => $row, 'message' => $message];
        }
    }
}
