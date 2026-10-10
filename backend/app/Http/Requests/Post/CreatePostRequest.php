<?php

namespace App\Http\Requests\Post;

use Illuminate\Foundation\Http\FormRequest;

class CreatePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'body' => ['nullable', 'string', 'max:5000', 'required_without_all:media,video'],
            'media' => ['nullable', 'array', 'max:10', 'prohibits:video'],
            'media.*' => ['image', 'max:8192'],
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/quicktime,video/webm', 'max:51200', 'prohibits:media'],
            'video_duration_seconds' => ['nullable', 'integer', 'min:1', 'max:60'],
            'video_thumbnail' => ['nullable', 'image', 'max:2048'],
            'product_ids' => ['nullable', 'array'],
            'product_ids.*' => ['string', 'exists:products,id'],
        ];
    }
}
