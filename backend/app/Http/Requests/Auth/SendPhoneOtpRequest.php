<?php

namespace App\Http\Requests\Auth;

use App\Support\PhoneNumber;
use Illuminate\Foundation\Http\FormRequest;

class SendPhoneOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['phone' => PhoneNumber::normalize($this->string('phone')->toString())]);
    }

    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'max:20'],
        ];
    }
}
