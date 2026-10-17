<?php

namespace App\Support\DataTransfer;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Describes how one resource (categories, products, ...) maps to spreadsheet
 * rows. Register implementations in DataTransferRegistry::HANDLERS.
 */
interface TransferHandler
{
    /** Human readable name, used in file names and UI. */
    public function label(): string;

    /** @return array<int, string> Column headers, in file order. */
    public function headers(): array;

    /** @return array<string, string|null> One example row for the import template. */
    public function sampleRow(): array;

    /** @param  array<string, mixed>  $filters */
    public function exportQuery(array $filters): Builder;

    /** @return array<string, string|int|float|null> Row keyed by header. */
    public function exportRow(Model $model): array;

    /**
     * Reorder rows before import (e.g. parents before children). Keys are the
     * original file row numbers and must be preserved.
     *
     * @param  array<int, array<string, string|null>>  $rows
     * @return array<int, array<string, string|null>>
     */
    public function prepareImport(array $rows): array;

    /**
     * Create or update one record from a row keyed by header.
     *
     * @param  array<string, string|null>  $row
     * @return string ImportResult::CREATED or ImportResult::UPDATED
     *
     * @throws RowSkippedException when the row is invalid
     */
    public function importRow(array $row): string;
}
