<?php

namespace App\Http\Requests\Auth;

use App\Support\PhoneNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'string', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:20', 'unique:users,phone'],
            'gender' => ['nullable', 'string', 'in:male,female'],
            'date_of_birth' => ['nullable', 'date', 'before:today'],
            'password' => ['required', 'confirmed', Password::min(8)->mixedCase()->numbers()],
            'terms_agreed' => ['required', 'accepted'],
            'province_code' => ['nullable', 'string', 'exists:indonesia_provinces,code'],
            'city_code' => ['nullable', 'string', 'exists:indonesia_cities,code'],
            'district_code' => ['nullable', 'string', 'exists:indonesia_districts,code'],
            'village_code' => ['nullable', 'string', 'exists:indonesia_villages,code'],
        ];
    }
}
