<?php

namespace App\Http\Requests\Admin;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class FlashSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'is_active' => ['nullable', 'boolean'],
            'products' => ['required', 'array', 'min:1'],
            'products.*.product_id' => ['required', 'string', 'distinct', 'exists:products,id'],
            'products.*.flash_sale_price' => ['required', 'numeric', 'min:0'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Nama flash sale wajib diisi.',
            'starts_at.required' => 'Waktu mulai wajib diisi.',
            'ends_at.required' => 'Waktu selesai wajib diisi.',
            'ends_at.after' => 'Waktu selesai harus setelah waktu mulai.',
            'products.required' => 'Pilih minimal satu produk.',
            'products.min' => 'Pilih minimal satu produk.',
            'products.*.product_id.distinct' => 'Produk yang sama dipilih lebih dari sekali.',
            'products.*.flash_sale_price.required' => 'Harga flash sale wajib diisi untuk setiap produk.',
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                $rows = collect($this->input('products', []));
                $regular = Product::query()
                    ->whereIn('id', $rows->pluck('product_id')->filter())
                    ->get(['id', 'name', 'regular_price'])
                    ->keyBy('id');

                foreach ($rows as $index => $row) {
                    $product = $regular->get($row['product_id'] ?? null);

                    if ($product && is_numeric($row['flash_sale_price'] ?? null)
                        && (float) $row['flash_sale_price'] >= (float) $product->regular_price) {
                        $validator->errors()->add(
                            "products.{$index}.flash_sale_price",
                            "Harga flash sale {$product->name} harus lebih murah dari harga normal."
                        );
                    }
                }
            },
        ];
    }
}
