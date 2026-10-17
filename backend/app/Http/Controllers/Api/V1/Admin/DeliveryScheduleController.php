<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliverySchedule;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeliveryScheduleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $items = DeliverySchedule::query()
            ->when($request->filled('shipping_method_id'), fn ($q) => $q->where('shipping_method_id', $request->string('shipping_method_id')->toString()))
            ->orderBy('start_time')
            ->orderBy('sort_order')
            ->get();

        return ApiResponse::success($items->map(fn ($s) => $this->present($s)), 'Delivery schedules retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $data = [
            ...$request->validate(['shipping_method_id' => ['required', 'string', 'exists:shipping_methods,id']]),
            ...$this->validated($request),
        ];
        $data['sort_order'] ??= (int) DeliverySchedule::where('shipping_method_id', $data['shipping_method_id'])->max('sort_order') + 1;

        return ApiResponse::success($this->present(DeliverySchedule::create($data)->fresh()), 'Delivery schedule created successfully.', [], 201);
    }

    public function update(Request $request, DeliverySchedule $deliverySchedule): JsonResponse
    {
        $deliverySchedule->update($this->validated($request));

        return ApiResponse::success($this->present($deliverySchedule->fresh()), 'Delivery schedule updated successfully.');
    }

    public function destroy(DeliverySchedule $deliverySchedule): JsonResponse
    {
        // Orders keep their delivery_slot snapshot; the FK is nulled on delete.
        $deliverySchedule->delete();

        return ApiResponse::success(null, 'Delivery schedule deleted successfully.');
    }

    private function validated(Request $request): array
    {
        $data = $request->validate([
            'label' => ['required', 'string', 'max:100'],
            'start_time' => ['required', 'date_format:H:i'],
            'end_time' => ['required', 'date_format:H:i', 'after:start_time'],
            'cutoff_minutes' => ['required', 'integer', 'min:0', 'max:10080'],
            'quota' => ['nullable', 'integer', 'min:1'],
            'days' => ['nullable', 'array'],
            'days.*' => ['integer', 'between:1,7'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ], [
            'end_time.after' => 'Jam selesai harus setelah jam mulai.',
        ]);

        if (array_key_exists('days', $data)) {
            $days = array_values(array_unique(array_map('intval', $data['days'] ?? [])));
            sort($days);
            // All seven days is the same as "every day".
            $data['days'] = $days === [] || count($days) === 7 ? null : $days;
        }

        return $data;
    }

    private function present(DeliverySchedule $s): array
    {
        return [
            'id' => $s->id,
            'shipping_method_id' => $s->shipping_method_id,
            'label' => $s->label,
            'start_time' => substr($s->start_time, 0, 5),
            'end_time' => substr($s->end_time, 0, 5),
            'cutoff_minutes' => $s->cutoff_minutes,
            'quota' => $s->quota,
            'days' => $s->days,
            'is_active' => $s->is_active,
            'sort_order' => $s->sort_order,
        ];
    }
}
