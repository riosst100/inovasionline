<?php

namespace App\Http\Requests\Verification;

use Illuminate\Foundation\Http\FormRequest;

class UserVerificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            'id_number' => ['nullable', 'string', 'max:50'],
            'selfie' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:4096'],
            'document' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:4096'],
        ];
    }
}
