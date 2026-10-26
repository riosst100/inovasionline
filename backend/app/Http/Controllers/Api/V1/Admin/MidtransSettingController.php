<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\MidtransSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MidtransSettingController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(MidtransSetting::current()->toPayload(), 'Midtrans settings retrieved successfully.');
    }

    /** A blank server key keeps the stored one, since the panel never receives it back. */
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'mode' => ['required', Rule::in(MidtransSetting::MODES)],
            'sandbox.client_key' => ['nullable', 'string', 'max:255'],
            'sandbox.server_key' => ['nullable', 'string', 'max:255'],
            'production.client_key' => ['nullable', 'string', 'max:255'],
            'production.server_key' => ['nullable', 'string', 'max:255'],
        ]);

        // Starts from the .env fallback on the first save, so keys already in .env carry over.
        $setting = MidtransSetting::current();
        $setting->mode = $data['mode'];

        foreach (MidtransSetting::MODES as $mode) {
            $clientKey = trim((string) ($data[$mode]['client_key'] ?? ''));
            $serverKey = trim((string) ($data[$mode]['server_key'] ?? ''));

            // Sandbox keys start with "SB-"; mixing them up is what makes Midtrans answer 401.
            foreach (['client_key' => $clientKey, 'server_key' => $serverKey] as $field => $key) {
                if ($key !== '' && str_starts_with($key, 'SB-') !== ($mode === 'sandbox')) {
                    throw ValidationException::withMessages([
                        "$mode.$field" => $mode === 'sandbox'
                            ? 'Key sandbox harus diawali "SB-". Key ini sepertinya key production.'
                            : 'Key ini key sandbox (diawali "SB-"). Gunakan key dari dashboard Midtrans mode Production.',
                    ]);
                }
            }

            $setting->{"{$mode}_client_key"} = $clientKey !== '' ? $clientKey : null;
            if ($serverKey !== '') {
                $setting->{"{$mode}_server_key"} = $serverKey;
            }
        }

        if ($setting->serverKey() === '') {
            throw ValidationException::withMessages([
                "{$setting->mode}.server_key" => 'Server key mode '.$setting->mode.' wajib diisi agar pembayaran bisa berjalan.',
            ]);
        }

        $setting->save();

        return ApiResponse::success($setting->toPayload(), 'Pengaturan Midtrans berhasil disimpan.');
    }
}
