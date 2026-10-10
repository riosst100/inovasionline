<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class FaceProfileUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'selfie' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:8192'],
        ];
    }
}
