<?php

namespace App\Http\Requests\Seller;

use App\Support\Enums\ShippingMethodType;
use App\Support\Enums\ShippingRateType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ShippingMethodRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'string', Rule::enum(ShippingMethodType::class)],
            'rate_type' => ['nullable', 'string', Rule::enum(ShippingRateType::class)],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'base_fee' => ['required', 'numeric', 'min:0'],
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'estimated_delivery_time' => ['nullable', 'string', 'max:255'],
            'pickup_address' => ['nullable', 'string', 'max:255'],
            'pickup_instructions' => ['nullable', 'string'],
            'pickup_hours' => ['nullable', 'array'],
            'delivery_radius_km' => ['nullable', 'numeric', 'min:0'],
            'free_shipping_min_amount' => ['nullable', 'numeric', 'min:0'],
            'is_enabled' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
