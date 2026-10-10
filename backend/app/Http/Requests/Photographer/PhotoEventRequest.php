<?php

namespace App\Http\Requests\Photographer;

use Illuminate\Foundation\Http\FormRequest;

class PhotoEventRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'event_date' => ['nullable', 'date'],
            'cover_photo' => ['nullable', 'image', 'max:8192'],
        ];
    }
}
