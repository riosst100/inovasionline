<?php

namespace App\Http\Requests\Seller;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PaymentMethodRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'string', Rule::in(['cash', 'bank_transfer', 'cash_on_delivery'])],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'instructions' => ['nullable', 'string'],
            'bank_name' => ['required_if:type,bank_transfer', 'nullable', 'string', 'max:255'],
            'account_number' => ['required_if:type,bank_transfer', 'nullable', 'string', 'max:100'],
            'account_holder_name' => ['required_if:type,bank_transfer', 'nullable', 'string', 'max:255'],
            'is_enabled' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
