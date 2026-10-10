<?php

namespace App\Http\Requests\Seller;

use App\Support\Enums\OrderStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateOrderStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', 'string', Rule::enum(OrderStatus::class)],
            'seller_notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
