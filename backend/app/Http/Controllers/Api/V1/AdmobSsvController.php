<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AdmobSetting;
use App\Models\AdReward;
use App\Models\User;
use App\Services\AdmobSsvVerifier;
use App\Services\AdRewardService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;

/**
 * AdMob's server-side verification callback for rewarded ads (set as the ad
 * unit's SSV URL in AdMob). Anything but a 200 makes AdMob retry, so valid
 * callbacks that unlock nothing (unknown user, foreign ad unit) still get 200.
 */
class AdmobSsvController extends Controller
{
    public function __construct(
        private readonly AdmobSsvVerifier $verifier,
        private readonly AdRewardService $rewards,
    ) {}

    public function __invoke(Request $request): Response
    {
        // Raw, as signed: Request::getQueryString() would re-sort and re-encode it.
        if (! $this->verifier->verify((string) $request->server('QUERY_STRING'))) {
            return response('invalid signature', 403);
        }

        $userId = (string) $request->query('user_id', '');
        $transactionId = (string) $request->query('transaction_id', '');
        $adUnit = (string) $request->query('ad_unit', '');

        // AdMob's "Verify URL" test sends no user.
        $user = $userId !== '' ? User::find($userId) : null;
        if ($user === null || $transactionId === '') {
            return response('ok');
        }

        if (! AdmobSetting::current()->isOwnRewardedUnit($adUnit)) {
            Log::warning('AdMob SSV: callback for an ad unit that is not configured', ['ad_unit' => $adUnit]);

            return response('ok');
        }

        $this->rewards->record($user, $transactionId, $adUnit, AdReward::PURPOSE_BONUS);

        return response('ok');
    }
}
