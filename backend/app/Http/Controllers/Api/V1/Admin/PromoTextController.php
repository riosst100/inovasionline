<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\FreeShippingSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Tampilan > Tulisan Promosi: the sliding texts in the strip on the app home screen. */
class PromoTextController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(['promo_texts' => FreeShippingSetting::current()->toPayload()['promo_texts']], 'Promo texts retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'promo_texts' => ['present', 'array', 'max:10'],
            'promo_texts.*' => ['nullable', 'string', 'max:120'],
        ]);

        $texts = array_values(array_filter(array_map(fn ($t) => trim((string) $t), $data['promo_texts'])));

        $setting = FreeShippingSetting::query()->first() ?? new FreeShippingSetting;
        $setting->fill(['promo_texts' => $texts]);
        $setting->save();

        return ApiResponse::success(['promo_texts' => $texts], 'Tulisan promosi berhasil disimpan.');
    }
}
