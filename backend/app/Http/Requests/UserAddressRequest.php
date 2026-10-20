<?php

namespace App\Http\Requests;

use App\Models\UserAddress;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UserAddressRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** Same limits as the address fields on CheckoutRequest. */
    public function rules(): array
    {
        return [
            'label' => ['required', 'string', Rule::in(UserAddress::LABELS)],
            'recipient_name' => ['required', 'string', 'max:255'],
            'recipient_phone' => ['required', 'string', 'max:30'],
            'province_code' => ['required', 'string', 'exists:indonesia_provinces,code'],
            'city_code' => ['required', 'string', 'exists:indonesia_cities,code'],
            'district_code' => ['required', 'string', 'exists:indonesia_districts,code'],
            'village_code' => ['required', 'string', 'exists:indonesia_villages,code'],
            'address_detail' => ['required', 'string', 'max:500'],
        ];
    }
}
