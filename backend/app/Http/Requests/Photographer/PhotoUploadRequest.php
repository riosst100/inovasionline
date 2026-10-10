<?php

namespace App\Http\Requests\Photographer;

use Illuminate\Foundation\Http\FormRequest;

class PhotoUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'photo' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:16384'],
            'price' => ['nullable', 'numeric', 'min:0'],
            'photo_event_id' => ['nullable', 'string', 'exists:photo_events,id'],
        ];
    }
}
