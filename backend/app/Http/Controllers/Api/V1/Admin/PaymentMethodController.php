<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentMethodResource;
use App\Models\PaymentMethod;
use App\Support\Enums\PaymentMethodType;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PaymentMethodController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $methods = PaymentMethod::query()
            ->when($request->has('is_enabled'), fn ($q) => $q->where('is_enabled', $request->boolean('is_enabled')))
            ->when($request->boolean('manual_only'), fn ($q) => $q->whereIn('type', PaymentMethodType::MANUAL_ACCOUNT_TYPES))
            ->orderBy('sort_order')
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($methods, PaymentMethodResource::class, 'Payment methods retrieved successfully.');
    }

    /** Admin-owned bank and e-wallet accounts used for manual checkout and manual top-up transfers. */
    public function accounts(Request $request): JsonResponse
    {
        $accounts = PaymentMethod::query()
            ->whereIn('type', PaymentMethodType::MANUAL_ACCOUNT_TYPES)
            ->when($request->filled('type'), fn ($q) => $q->where('type', $request->string('type')->toString()))
            ->when($request->has('is_enabled'), fn ($q) => $q->where('is_enabled', $request->boolean('is_enabled')))
            ->orderBy('sort_order')
            ->orderBy('bank_name')
            ->orderBy('name')
            ->get();

        return ApiResponse::success(PaymentMethodResource::collection($accounts), 'Bank and e-wallet accounts retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $method = PaymentMethod::create([
            ...$data,
            'name' => $data['name'] ?? $data['bank_name'],
            'is_enabled' => $request->boolean('is_enabled', true),
            'sort_order' => (int) PaymentMethod::max('sort_order') + 1,
        ]);

        return ApiResponse::success(new PaymentMethodResource($method->fresh()), 'Rekening/E-Wallet berhasil ditambahkan.', [], 201);
    }

    public function update(Request $request, PaymentMethod $paymentMethod): JsonResponse
    {
        if (! $paymentMethod->isManualAccount()) {
            return ApiResponse::error('Metode pembayaran sistem tidak dapat diubah dari menu ini.', [], 422);
        }

        $data = $this->validated($request);

        $paymentMethod->update([
            ...$data,
            'name' => $data['name'] ?? $data['bank_name'],
            'is_enabled' => $request->boolean('is_enabled', $paymentMethod->is_enabled),
        ]);

        return ApiResponse::success(new PaymentMethodResource($paymentMethod->fresh()), 'Rekening/E-Wallet berhasil diperbarui.');
    }

    public function toggle(PaymentMethod $paymentMethod): JsonResponse
    {
        $paymentMethod->update(['is_enabled' => ! $paymentMethod->is_enabled]);

        return ApiResponse::success(new PaymentMethodResource($paymentMethod->fresh()), 'Status metode pembayaran diperbarui.');
    }

    public function destroy(PaymentMethod $paymentMethod): JsonResponse
    {
        if (! $paymentMethod->isManualAccount()) {
            return ApiResponse::error('Metode pembayaran sistem tidak dapat dihapus.', [], 422);
        }

        $paymentMethod->delete();

        return ApiResponse::success(null, 'Rekening/E-Wallet berhasil dihapus.');
    }

    private function validated(Request $request): array
    {
        $validated = $request->validate([
            'type' => ['required', Rule::in(PaymentMethodType::MANUAL_ACCOUNT_TYPES)],
            'bank_name' => ['required', 'string', 'max:100'],
            'account_number' => ['required', 'string', 'max:100'],
            'account_holder_name' => ['required', 'string', 'max:150'],
            'name' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:255'],
            'instructions' => ['nullable', 'string', 'max:1000'],
            'is_enabled' => ['sometimes', 'boolean'],
        ], [
            'type.required' => 'Jenis wajib dipilih (Bank atau E-Wallet).',
            'type.in' => 'Jenis harus berupa Bank atau E-Wallet.',
            'bank_name.required' => 'Nama bank atau e-wallet wajib diisi.',
            'account_number.required' => 'Nomor rekening atau nomor e-wallet wajib diisi.',
            'account_holder_name.required' => 'Atas nama pemilik rekening wajib diisi.',
        ]);

        $bankName = trim($validated['bank_name']);
        $name = isset($validated['name']) && trim($validated['name']) !== '' ? trim($validated['name']) : $bankName;

        return [
            'type' => $validated['type'],
            'bank_name' => $bankName,
            'account_number' => trim($validated['account_number']),
            'account_holder_name' => trim($validated['account_holder_name']),
            'name' => $name,
            'description' => isset($validated['description']) && trim($validated['description']) !== '' ? trim($validated['description']) : null,
            'instructions' => isset($validated['instructions']) && trim($validated['instructions']) !== '' ? trim($validated['instructions']) : null,
        ];
    }
}
