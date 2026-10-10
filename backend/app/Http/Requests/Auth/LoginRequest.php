<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'login' => ['required_without:email', 'string'],
            'email' => ['required_without:login', 'string'],
            'password' => ['required', 'string'],
            'remember' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * The submitted identifier, from either the new "login" field (email or
     * phone) or the legacy "email" field kept for backward compatibility.
     */
    public function identifier(): string
    {
        return $this->string('login')->toString() ?: $this->string('email')->toString();
    }
}
