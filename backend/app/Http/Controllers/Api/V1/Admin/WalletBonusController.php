<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\WalletBonusSetting;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/** Promosi > Bonus Saldo Belanja: amounts and odds of the one-time bonus. */
class WalletBonusController extends Controller
{
    public function show(): JsonResponse
    {
        return ApiResponse::success(WalletBonusSetting::current()->toPayload(), 'Wallet bonus settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'step' => ['required', 'integer', 'min:1', 'max:100000'],
            'tiers' => ['required', 'array', 'min:1', 'max:10'],
            'tiers.*.from' => ['required', 'integer', 'min:1', 'max:10000000'],
            'tiers.*.to' => ['required', 'integer', 'gte:tiers.*.from', 'max:10000000'],
            'tiers.*.weight' => ['required', 'integer', 'min:0', 'max:100'],
        ], [
            'tiers.*.to.gte' => 'Nominal maksimum tiap rentang harus ≥ nominal minimumnya.',
        ]);

        if (array_sum(array_column($data['tiers'], 'weight')) !== 100) {
            throw ValidationException::withMessages(['tiers' => 'Total persentase semua rentang harus 100%.']);
        }

        foreach ($data['tiers'] as $i => $tier) {
            if (intdiv($tier['to'], $data['step']) * $data['step'] < $tier['from']) {
                throw ValidationException::withMessages([
                    "tiers.$i.from" => 'Rentang '.($i + 1).' tidak memuat kelipatan Rp'.number_format($data['step'], 0, ',', '.').'.',
                ]);
            }
        }

        $setting = WalletBonusSetting::query()->first() ?? new WalletBonusSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($setting->toPayload(), 'Bonus saldo belanja berhasil disimpan.');
    }
}
