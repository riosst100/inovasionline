<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PhotoPurchaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'photo_id' => ['required', 'string', 'exists:photos,id'],
            'matched_face_index' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
