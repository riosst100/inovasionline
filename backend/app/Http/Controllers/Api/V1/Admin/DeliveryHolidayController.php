<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliveryHoliday;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DeliveryHolidayController extends Controller
{
    /** Upcoming holidays (past ones are hidden unless ?include_past=1). */
    public function index(Request $request): JsonResponse
    {
        $items = DeliveryHoliday::query()
            ->with('shippingMethod:id,name')
            ->when($request->filled('shipping_method_id'), fn ($q) => $q->forMethod($request->string('shipping_method_id')->toString()))
            ->unless($request->boolean('include_past'), fn ($q) => $q->where('date', '>=', now('Asia/Jakarta')->toDateString()))
            ->orderBy('date')
            ->get();

        return ApiResponse::success($items->map(fn ($h) => $this->present($h)), 'Delivery holidays retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $holiday = DeliveryHoliday::create($this->validated($request));

        return ApiResponse::success($this->present($holiday->load('shippingMethod:id,name')), 'Delivery holiday created successfully.', [], 201);
    }

    public function update(Request $request, DeliveryHoliday $deliveryHoliday): JsonResponse
    {
        $deliveryHoliday->update($this->validated($request, $deliveryHoliday));

        return ApiResponse::success($this->present($deliveryHoliday->fresh()->load('shippingMethod:id,name')), 'Delivery holiday updated successfully.');
    }

    public function destroy(DeliveryHoliday $deliveryHoliday): JsonResponse
    {
        $deliveryHoliday->delete();

        return ApiResponse::success(null, 'Delivery holiday deleted successfully.');
    }

    private function validated(Request $request, ?DeliveryHoliday $ignore = null): array
    {
        $methodId = $request->input('shipping_method_id') ?: null;

        $data = $request->validate([
            'shipping_method_id' => ['nullable', 'string', 'exists:shipping_methods,id'],
            'date' => [
                'required',
                'date_format:Y-m-d',
                Rule::unique('delivery_holidays', 'date')
                    ->where(fn ($q) => $methodId ? $q->where('shipping_method_id', $methodId) : $q->whereNull('shipping_method_id'))
                    ->ignore($ignore?->id),
            ],
            'name' => ['required', 'string', 'max:100'],
        ], [
            'date.unique' => 'Tanggal ini sudah terdaftar sebagai hari libur.',
        ]);
        $data['shipping_method_id'] = $methodId;

        return $data;
    }

    private function present(DeliveryHoliday $h): array
    {
        return [
            'id' => $h->id,
            'shipping_method_id' => $h->shipping_method_id,
            'shipping_method_name' => $h->shippingMethod?->name,
            'date' => $h->date->toDateString(),
            'name' => $h->name,
        ];
    }
}
