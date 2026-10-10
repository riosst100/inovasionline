<?php

namespace App\Http\Requests\Seller;

use Illuminate\Foundation\Http\FormRequest;

class ShippingMethodRateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'district_code' => ['required_without:village_code', 'nullable', 'string', 'exists:indonesia_districts,code'],
            'village_code' => ['nullable', 'string', 'exists:indonesia_villages,code'],
            'fee' => ['required', 'numeric', 'min:0'],
        ];
    }
}
