<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class BannerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->input('link_url') === '') {
            $this->merge(['link_url' => null]);
        }
    }

    public function rules(): array
    {
        $isCreate = $this->route('banner') === null;

        return [
            'name' => ['required', 'string', 'max:255'],
            'image' => [$isCreate ? 'required' : 'nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'link_url' => ['nullable', 'url', 'max:2048'],
            'is_active' => ['nullable', 'boolean'],
        ];
    }
}
