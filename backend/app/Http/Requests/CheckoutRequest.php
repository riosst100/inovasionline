<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CheckoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'store_id' => ['required', 'string', 'exists:stores,id'],
            'cart_item_ids' => ['nullable', 'array', 'min:1'],
            'cart_item_ids.*' => ['string', 'exists:cart_items,id'],
            'payment_method_id' => ['required', 'string', 'exists:payment_methods,id'],
            'shipping_method_id' => ['required', 'string', 'exists:shipping_methods,id'],
            'recipient_name' => ['required', 'string', 'max:255'],
            'recipient_phone' => ['required', 'string', 'max:30'],
            'province_code' => ['required', 'string', 'exists:indonesia_provinces,code'],
            'city_code' => ['required', 'string', 'exists:indonesia_cities,code'],
            'district_code' => ['required', 'string', 'exists:indonesia_districts,code'],
            'village_code' => ['required', 'string', 'exists:indonesia_villages,code'],
            'address_detail' => ['required', 'string', 'max:500'],
            'customer_notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
