<?php

namespace App\Http\Resources;

use App\Models\DataTransfer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin DataTransfer */
class DataTransferResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            // `$this->resource` is the wrapped model itself, so read the column explicitly.
            'resource' => $this->resource->getAttribute('resource'),
            'format' => $this->format,
            'status' => $this->status,
            'file_name' => $this->file_name,
            'has_file' => $this->file_path !== null,
            'total_rows' => $this->total_rows,
            'processed_rows' => $this->processed_rows,
            'created_rows' => $this->created_rows,
            'updated_rows' => $this->updated_rows,
            'failed_rows' => $this->failed_rows,
            'progress' => $this->isFinished() && $this->status === DataTransfer::STATUS_COMPLETED
                ? 100
                : ($this->total_rows > 0 ? (int) floor($this->processed_rows / $this->total_rows * 100) : 0),
            // Omitted from listings (the column is not selected) to keep polling light.
            'row_errors' => $this->when(
                array_key_exists('row_errors', $this->resource->getAttributes()),
                fn () => $this->row_errors ?? [],
            ),
            'error_message' => $this->error_message,
            'admin_user' => $this->whenLoaded('adminUser', fn () => $this->adminUser
                ? ['id' => $this->adminUser->id, 'name' => $this->adminUser->name]
                : null),
            'started_at' => $this->started_at?->toIso8601String(),
            'finished_at' => $this->finished_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
