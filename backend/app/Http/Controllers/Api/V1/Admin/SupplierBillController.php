<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\SupplierBill;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Keuangan > Tagihan Supplier: bills the platform owes its suppliers. */
class SupplierBillController extends Controller
{
    private const DUE_SOON_DAYS = 7;

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'status' => ['nullable', Rule::in([SupplierBill::STATUS_UNPAID, SupplierBill::STATUS_OVERDUE, SupplierBill::STATUS_PAID])],
            'supplier_id' => ['nullable', 'string', 'max:26'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $bills = SupplierBill::query()
            ->with('supplier:id,name')
            ->when($data['status'] ?? null, fn ($q, $status) => $q->withStatus($status))
            ->when($data['supplier_id'] ?? null, fn ($q, $id) => $q->where('supplier_id', $id))
            ->when($data['search'] ?? null, fn ($q, $search) => $q->where(fn ($q) => $q
                ->where('bill_number', 'ilike', "%{$search}%")
                ->orWhereHas('supplier', fn ($q) => $q->where('name', 'ilike', "%{$search}%"))))
            // Unpaid first, soonest due first; paid ones by payment date.
            ->orderByRaw('paid_at is not null')
            ->orderByRaw('due_date is null')
            ->orderBy('due_date')
            ->orderByDesc('paid_at')
            ->orderByDesc('bill_date')
            ->paginate($data['per_page'] ?? 20);

        $today = SupplierBill::today();
        $dueSoon = now(WalletTopupController::TIMEZONE)->addDays(self::DUE_SOON_DAYS)->toDateString();
        $monthStart = WalletTopupController::startOfDay(now(WalletTopupController::TIMEZONE)->startOfMonth()->toDateString());

        $summary = SupplierBill::query()->toBase()->selectRaw('
            coalesce(sum(amount) filter (where paid_at is null), 0) as outstanding,
            count(*) filter (where paid_at is null) as outstanding_count,
            coalesce(sum(amount) filter (where paid_at is null and due_date < ?), 0) as overdue,
            count(*) filter (where paid_at is null and due_date < ?) as overdue_count,
            coalesce(sum(amount) filter (where paid_at is null and due_date >= ? and due_date <= ?), 0) as due_soon,
            count(*) filter (where paid_at is null and due_date >= ? and due_date <= ?) as due_soon_count,
            coalesce(sum(amount) filter (where paid_at >= ?), 0) as paid_this_month
        ', [$today, $today, $today, $dueSoon, $today, $dueSoon, $monthStart])->first();

        return ApiResponse::success(
            collect($bills->items())->map(fn (SupplierBill $b) => $this->transform($b)),
            'Supplier bills retrieved successfully.',
            [
                'current_page' => $bills->currentPage(),
                'last_page' => $bills->lastPage(),
                'per_page' => $bills->perPage(),
                'total' => $bills->total(),
                'summary' => [
                    'outstanding' => (float) $summary->outstanding,
                    'outstanding_count' => (int) $summary->outstanding_count,
                    'overdue' => (float) $summary->overdue,
                    'overdue_count' => (int) $summary->overdue_count,
                    'due_soon' => (float) $summary->due_soon,
                    'due_soon_count' => (int) $summary->due_soon_count,
                    'due_soon_days' => self::DUE_SOON_DAYS,
                    'paid_this_month' => (float) $summary->paid_this_month,
                ],
            ]
        );
    }

    public function store(Request $request): JsonResponse
    {
        $bill = SupplierBill::create($request->validate($this->rules($request), $this->messages()));

        return ApiResponse::success($this->transform($bill->load('supplier:id,name')), 'Tagihan berhasil ditambahkan.', [], 201);
    }

    public function update(Request $request, SupplierBill $supplierBill): JsonResponse
    {
        $supplierBill->update($request->validate($this->rules($request, $supplierBill), $this->messages()));

        return ApiResponse::success($this->transform($supplierBill->fresh('supplier:id,name')), 'Tagihan berhasil diperbarui.');
    }

    public function destroy(SupplierBill $supplierBill): JsonResponse
    {
        if ($supplierBill->paid_at) {
            return ApiResponse::error('Tagihan yang sudah lunas tidak dapat dihapus. Batalkan status lunas terlebih dahulu.', [], 422);
        }

        $supplierBill->delete();

        return ApiResponse::success(null, 'Tagihan berhasil dihapus.');
    }

    public function pay(Request $request, SupplierBill $supplierBill): JsonResponse
    {
        $data = $request->validate([
            'paid_date' => ['nullable', 'date_format:Y-m-d', 'before_or_equal:'.SupplierBill::today()],
            'payment_notes' => ['nullable', 'string', 'max:255'],
        ]);

        if ($supplierBill->paid_at) {
            return ApiResponse::error('Tagihan ini sudah lunas.', [], 422);
        }

        $supplierBill->update([
            // A back-dated payment counts at noon WIB of that day, so it stays inside that day in reports.
            'paid_at' => isset($data['paid_date'])
                ? WalletTopupController::startOfDay($data['paid_date'])->addHours(12)
                : now(),
            'payment_notes' => $data['payment_notes'] ?? null,
        ]);

        return ApiResponse::success($this->transform($supplierBill->fresh('supplier:id,name')), 'Tagihan ditandai lunas.');
    }

    public function unpay(SupplierBill $supplierBill): JsonResponse
    {
        $supplierBill->update(['paid_at' => null, 'payment_notes' => null]);

        return ApiResponse::success($this->transform($supplierBill->fresh('supplier:id,name')), 'Status lunas dibatalkan.');
    }

    private function rules(Request $request, ?SupplierBill $bill = null): array
    {
        return [
            'supplier_id' => ['required', 'exists:suppliers,id'],
            'bill_number' => [
                'required', 'string', 'max:60',
                Rule::unique('supplier_bills')->where('supplier_id', $request->input('supplier_id'))->ignore($bill?->id),
            ],
            'bill_date' => ['required', 'date_format:Y-m-d'],
            'due_date' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:bill_date'],
            'amount' => ['required', 'numeric', 'min:1'],
            'notes' => ['nullable', 'string', 'max:255'],
        ];
    }

    private function messages(): array
    {
        return [
            'bill_number.unique' => 'Nomor tagihan ini sudah ada untuk supplier tersebut.',
            'due_date.after_or_equal' => 'Jatuh tempo tidak boleh sebelum tanggal tagihan.',
        ];
    }

    private function transform(SupplierBill $bill): array
    {
        return [
            'id' => $bill->id,
            'supplier_id' => $bill->supplier_id,
            'supplier_name' => $bill->supplier?->name,
            'bill_number' => $bill->bill_number,
            'bill_date' => $bill->bill_date?->toDateString(),
            'due_date' => $bill->due_date?->toDateString(),
            'amount' => (float) $bill->amount,
            'notes' => $bill->notes,
            'status' => $bill->status(),
            'paid_at' => $bill->paid_at,
            'payment_notes' => $bill->payment_notes,
            'created_at' => $bill->created_at,
        ];
    }
}
