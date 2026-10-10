<?php

namespace App\Http\Requests\Post;

use Illuminate\Foundation\Http\FormRequest;

class SharePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'body' => ['nullable', 'string', 'max:5000'],
        ];
    }
}
