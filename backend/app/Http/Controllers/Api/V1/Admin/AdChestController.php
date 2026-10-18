<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdChestSetting;
use App\Models\AdmobSetting;
use App\Services\AdChestService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/** Iklan > Peti Hadiah: chests per day, budget and the prize odds. */
class AdChestController extends Controller
{
    public function __construct(private readonly AdChestService $chests) {}

    public function show(): JsonResponse
    {
        return ApiResponse::success($this->payload(AdChestSetting::current()), 'Reward chest settings retrieved successfully.');
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'chests_per_day' => ['required', 'integer', 'min:1', 'max:20'],
            'daily_budget' => ['required', 'integer', 'min:0', 'max:100000000'],
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

        $setting = AdChestSetting::query()->first() ?? new AdChestSetting;
        $setting->fill($data)->save();

        return ApiResponse::success($this->payload($setting), 'Peti hadiah berhasil disimpan.');
    }

    private function payload(AdChestSetting $setting): array
    {
        $ads = AdmobSetting::current();

        return [
            ...$setting->toPayload(),
            // Read-only: the chest only shows while AdMob is on with a rewarded unit.
            'ads_ready' => $ads->is_active && ($ads->android_rewarded_id || $ads->ios_rewarded_id),
            'paid_today' => $this->chests->paidToday(),
        ];
    }
}
