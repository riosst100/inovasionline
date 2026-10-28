<?php

namespace App\Http\Requests\Admin;

use App\Models\Banner;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

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
        if ($this->input('image_url') === '') {
            $this->merge(['image_url' => null]);
        }
    }

    public function rules(): array
    {
        $isCreate = $this->route('banner') === null;

        return [
            'name' => [$isCreate ? 'required' : 'sometimes|required', 'string', 'max:255'],
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'image_url' => ['nullable', 'string', 'max:2048'],
            'link_url' => ['nullable', 'string', 'max:2048'],
            'placement' => ['nullable', Rule::in(Banner::PLACEMENTS)],
            'is_active' => ['nullable'],
            'sort_order' => ['nullable', 'integer'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $isCreate = $this->route('banner') === null;
            if ($isCreate && ! $this->hasFile('image') && empty($this->input('image_url'))) {
                $validator->errors()->add('image', 'Materi gambar banner wajib diunggah atau berupa URL gambar.');
            }
        });
    }
}
