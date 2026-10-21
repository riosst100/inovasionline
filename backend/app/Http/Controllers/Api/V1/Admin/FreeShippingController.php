<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\FreeShippingSetting;
use App\Models\PaymentMethod;
use App\Models\ShippingMethod;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** Promosi > Gratis Ongkir: which payment and shipping methods get free shipping. */
class FreeShippingController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(FreeShippingSetting::current()->toPayload(), 'Free shipping settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'min_subtotal' => ['nullable', 'numeric', 'min:0', 'max:1000000000'],
            'payment_method_ids' => ['present', 'array'],
            'payment_method_ids.*' => ['string', Rule::exists(PaymentMethod::class, 'id')],
            'shipping_method_ids' => ['present', 'array'],
            'shipping_method_ids.*' => ['string', Rule::exists(ShippingMethod::class, 'id')],
        ]);

        if ($data['is_active'] && (empty($data['payment_method_ids']) || empty($data['shipping_method_ids']))) {
            throw ValidationException::withMessages([
                'payment_method_ids' => 'Pilih minimal satu metode pembayaran dan satu metode pengiriman.',
            ]);
        }

        $setting = FreeShippingSetting::query()->first() ?? new FreeShippingSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Gratis ongkir berhasil disimpan.');
    }
}
