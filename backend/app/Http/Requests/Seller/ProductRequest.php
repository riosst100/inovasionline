<?php

namespace App\Http\Requests\Seller;

use App\Support\Enums\ProductStatus;
use App\Support\Enums\ProductType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'category_id' => ['nullable', 'string', 'exists:categories,id'],
            'name' => ['required', 'string', 'max:255'],
            'short_description' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:20000'],
            'product_type' => ['required', 'string', Rule::enum(ProductType::class)],

            'regular_price' => ['required', 'numeric', 'min:0'],
            'sale_price' => ['nullable', 'numeric', 'min:0', 'lt:regular_price'],
            'cost_price' => ['nullable', 'numeric', 'min:0'],
            'is_taxable' => ['nullable', 'boolean'],

            'sku' => ['nullable', 'string', 'max:255'],
            'stock' => ['nullable', 'integer', 'min:0'],
            'min_stock' => ['nullable', 'integer', 'min:0'],
            'track_inventory' => ['nullable', 'boolean'],

            'weight' => ['nullable', 'numeric', 'min:0'],
            'length' => ['nullable', 'numeric', 'min:0'],
            'width' => ['nullable', 'numeric', 'min:0'],
            'height' => ['nullable', 'numeric', 'min:0'],
            'requires_shipping' => ['nullable', 'boolean'],

            'status' => ['nullable', 'string', Rule::enum(ProductStatus::class)],

            'meta_title' => ['nullable', 'string', 'max:255'],
            'meta_description' => ['nullable', 'string', 'max:255'],

            'images' => ['nullable', 'array', 'max:8'],
            'images.*' => ['image', 'max:4096'],

            'existing_images' => ['nullable', 'array'],
            'existing_images.*' => ['string', 'exists:product_images,id'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $existingCount = count($this->input('existing_images', []));
            $newCount = count($this->file('images', []));

            if ($existingCount + $newCount === 0) {
                $validator->errors()->add('images', 'Produk harus memiliki minimal satu gambar.');
            }
        });
    }
}
