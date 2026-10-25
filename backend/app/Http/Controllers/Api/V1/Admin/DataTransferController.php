<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DataTransferResource;
use App\Jobs\ProcessDataTransferJob;
use App\Models\DataTransfer;
use App\Support\DataTransfer\DataTransferRegistry;
use App\Support\DataTransfer\SpreadsheetFile;
use App\Support\Permissions\AdminMenu;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Generic, queued CSV/XLSX import & export for any resource registered in
 * DataTransferRegistry (categories, products, ...).
 *
 * Allowed per resource: export/template/history need view on the resource's menu, import and
 * delete need manage; the Import / Export menu (data_transfers) grants both for every resource.
 */
class DataTransferController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'resource' => ['nullable', Rule::in(DataTransferRegistry::resources())],
            'type' => ['nullable', Rule::in([DataTransfer::TYPE_IMPORT, DataTransfer::TYPE_EXPORT])],
            'status' => ['nullable', 'string'],
        ]);

        $columns = array_diff((new DataTransfer)->getFillable(), ['row_errors', 'filters']);

        $transfers = DataTransfer::query()
            ->select(['id', 'created_at', 'updated_at', ...$columns])
            ->with('adminUser:id,name')
            ->whereIn('resource', array_filter(DataTransferRegistry::resources(), fn (string $r) => $this->allowed($request, $r, false)))
            ->when($request->string('resource')->toString(), fn ($q, $v) => $q->where('resource', $v))
            ->when($request->string('type')->toString(), fn ($q, $v) => $q->where('type', $v))
            ->when($request->string('status')->toString(), function ($q, $v) {
                $v === 'active'
                    ? $q->whereIn('status', [DataTransfer::STATUS_PENDING, DataTransfer::STATUS_PROCESSING])
                    : $q->where('status', $v);
            })
            ->latest()
            ->orderByDesc('id')
            ->paginate(min($request->integer('per_page', 20), 100));

        return ApiResponse::paginated($transfers, DataTransferResource::class, 'Data transfers retrieved successfully.');
    }

    public function show(Request $request, DataTransfer $dataTransfer): JsonResponse
    {
        if (! $this->allowed($request, $dataTransfer->resource, false)) {
            return $this->denied();
        }

        return ApiResponse::success(new DataTransferResource($dataTransfer->load('adminUser:id,name')));
    }

    public function export(Request $request): JsonResponse
    {
        $data = $request->validate([
            'resource' => ['required', Rule::in(DataTransferRegistry::resources())],
            'format' => ['required', Rule::in(SpreadsheetFile::FORMATS)],
            'filters' => ['nullable', 'array'],
        ]);

        if (! $this->allowed($request, $data['resource'], false)) {
            return $this->denied();
        }

        $handler = DataTransferRegistry::handler($data['resource']);

        $transfer = DataTransfer::create([
            'type' => DataTransfer::TYPE_EXPORT,
            'resource' => $data['resource'],
            'format' => $data['format'],
            'status' => DataTransfer::STATUS_PENDING,
            'file_name' => Str::slug($handler->label()).'-'.now()->format('Ymd-His').'.'.$data['format'],
            'filters' => $data['filters'] ?? [],
            'admin_user_id' => $request->user()->id,
        ]);

        ProcessDataTransferJob::dispatch($transfer);

        return ApiResponse::success(new DataTransferResource($transfer->load('adminUser:id,name')), 'Export sedang diproses.', [], 202);
    }

    public function import(Request $request): JsonResponse
    {
        $data = $request->validate([
            'resource' => ['required', Rule::in(DataTransferRegistry::resources())],
            'file' => ['required', 'file', 'max:20480', 'mimes:csv,txt,xlsx'],
        ]);

        if (! $this->allowed($request, $data['resource'], true)) {
            return $this->denied();
        }

        $file = $data['file'];
        $format = strtolower($file->getClientOriginalExtension()) === 'xlsx' ? 'xlsx' : 'csv';

        $transfer = DataTransfer::create([
            'type' => DataTransfer::TYPE_IMPORT,
            'resource' => $data['resource'],
            'format' => $format,
            'status' => DataTransfer::STATUS_PENDING,
            'file_name' => Str::limit($file->getClientOriginalName(), 200, ''),
            'admin_user_id' => $request->user()->id,
        ]);

        $transfer->update([
            'file_path' => $file->storeAs("data-transfers/{$transfer->id}", "source.{$format}", 'local'),
        ]);

        ProcessDataTransferJob::dispatch($transfer);

        return ApiResponse::success(new DataTransferResource($transfer->load('adminUser:id,name')), 'Import sedang diproses.', [], 202);
    }

    /** Export result, or the originally uploaded file for imports. */
    public function download(Request $request, DataTransfer $dataTransfer): StreamedResponse|JsonResponse
    {
        if (! $this->allowed($request, $dataTransfer->resource, false)) {
            return $this->denied();
        }

        if (! $dataTransfer->file_path ||! Storage::disk('local')->exists($dataTransfer->file_path)) {
            return ApiResponse::error('File tidak tersedia.', [], 404);
        }

        return Storage::disk('local')->download(
            $dataTransfer->file_path,
            $dataTransfer->file_name,
            ['Content-Type' => SpreadsheetFile::mimeType($dataTransfer->format)],
        );
    }

    public function template(Request $request): BinaryFileResponse|JsonResponse
    {
        $data = $request->validate([
            'resource' => ['required', Rule::in(DataTransferRegistry::resources())],
            'format' => ['required', Rule::in(SpreadsheetFile::FORMATS)],
        ]);

        if (! $this->allowed($request, $data['resource'], false)) {
            return $this->denied();
        }

        $handler = DataTransferRegistry::handler($data['resource']);
        $path = tempnam(sys_get_temp_dir(), 'template_');
        SpreadsheetFile::write($path, $data['format'], $handler->headers(), [$handler->sampleRow()]);

        return response()
            ->download($path, 'template-'.Str::slug($handler->label()).'.'.$data['format'], [
                'Content-Type' => SpreadsheetFile::mimeType($data['format']),
            ])
            ->deleteFileAfterSend();
    }

    public function destroy(Request $request, DataTransfer $dataTransfer): JsonResponse
    {
        if (! $this->allowed($request, $dataTransfer->resource, true)) {
            return $this->denied();
        }

        if (! $dataTransfer->isFinished()) {
            return ApiResponse::error('Proses yang sedang berjalan tidak bisa dihapus.', [], 422);
        }

        Storage::disk('local')->deleteDirectory("data-transfers/{$dataTransfer->id}");
        $dataTransfer->delete();

        return ApiResponse::success(null, 'Riwayat dihapus.');
    }

    private function allowed(Request $request, string $resource, bool $manage): bool
    {
        $can = $manage ? AdminMenu::canManage(...) : AdminMenu::canView(...);

        return $can($request->user(), 'data_transfers') || $can($request->user(), DataTransferRegistry::menu($resource));
    }

    private function denied(): JsonResponse
    {
        return ApiResponse::error('Anda tidak punya hak akses untuk data ini.', [], 403);
    }
}
