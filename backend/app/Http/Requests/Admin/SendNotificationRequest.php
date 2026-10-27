<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SendNotificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:1000'],
            'target' => ['required', Rule::in(['all', 'users'])],
            'user_ids' => ['required_if:target,users', 'array', 'max:500'],
            'user_ids.*' => ['string', 'exists:users,id'],
        ];
    }
}
