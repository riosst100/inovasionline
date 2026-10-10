<?php

namespace App\Http\Requests\Seller;

use App\Support\Enums\PromotionType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PromotionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'code' => ['nullable', 'string', 'max:50'],
            'type' => ['required', 'string', Rule::enum(PromotionType::class)],
            'discount_value' => ['required_unless:type,free_shipping', 'nullable', 'numeric', 'min:0'],
            'minimum_purchase' => ['nullable', 'numeric', 'min:0'],
            'maximum_discount' => ['nullable', 'numeric', 'min:0'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'is_active' => ['nullable', 'boolean'],

            'flash_sale_slot_id' => ['required', 'string', 'exists:flash_sale_slots,id'],
            'date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'],

            'product_ids' => ['required', 'array', 'min:1'],
            'product_ids.*' => ['string', 'exists:products,id'],
        ];
    }
}
