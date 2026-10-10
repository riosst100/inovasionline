<?php

namespace App\Http\Requests\Seller;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'parent_id' => [
                'required',
                'string',
                Rule::exists('categories', 'id')->where('is_active', true)->whereNull('parent_id'),
            ],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'icon' => ['nullable', 'string', 'max:255'],
        ];
    }
}
