<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PhotographerApplicationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'phone' => ['required', 'string', 'max:20'],
            'business_name' => ['nullable', 'string', 'max:255'],
            'portfolio_url' => ['nullable', 'string', 'url', 'max:255'],
            'id_card' => ['nullable', 'image', 'max:4096'],
        ];
    }
}
