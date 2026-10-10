<?php

namespace App\Http\Requests\Seller;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SellerApplicationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
            'store_name' => ['required', 'string', 'max:255'],
            'business_type' => ['required', 'string', Rule::in(['individual', 'company'])],
            'main_category_id' => ['nullable', 'string', 'exists:categories,id'],
            'business_description' => ['nullable', 'string', 'max:2000'],
            'address' => ['required', 'string', 'max:255'],
            'province' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'district' => ['nullable', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:10'],
        ];
    }
}
