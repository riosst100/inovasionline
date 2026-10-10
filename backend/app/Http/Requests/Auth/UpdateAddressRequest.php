<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAddressRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'province_code' => ['required', 'string', 'exists:indonesia_provinces,code'],
            'city_code' => ['required', 'string', 'exists:indonesia_cities,code'],
            'district_code' => ['required', 'string', 'exists:indonesia_districts,code'],
            'village_code' => ['required', 'string', 'exists:indonesia_villages,code'],
        ];
    }
}
