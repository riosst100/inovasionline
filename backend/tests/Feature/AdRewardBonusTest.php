<?php

namespace Tests\Feature;

use App\Models\AdmobSetting;
use App\Models\AdReward;
use App\Models\User;
use App\Services\AdmobSsvVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdRewardBonusTest extends TestCase
{
    use RefreshDatabase;

    private const KEY_ID = '1234567890';

    private const AD_UNIT = '5224354917';

    /** @var \OpenSSLAsymmetricKey */
    private $privateKey;

    protected function setUp(): void
    {
        parent::setUp();

        // Stands in for Google's signing key; its public half is served as the verifier key.
        $this->privateKey = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        $pem = openssl_pkey_get_details($this->privateKey)['key'];
        Http::fake([AdmobSsvVerifier::KEYS_URL => Http::response(['keys' => [['keyId' => (int) self::KEY_ID, 'pem' => $pem]]])]);

        AdmobSetting::create([
            'is_active' => true,
            'android_rewarded_id' => 'ca-app-pub-3940256099942544/'.self::AD_UNIT,
            'bonus_requires_ad' => true,
        ]);
    }

    public function test_bonus_claim_waits_for_a_verified_ad_view(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/wallet/bonus/claim')
            ->assertStatus(409)
            ->assertJsonPath('errors.code.0', 'ad_view_required');

        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-1'))->assertOk();

        $this->postJson('/api/v1/wallet/bonus/claim')->assertOk()->assertJsonPath('data.bonus_available', false);
        $this->assertNotNull(AdReward::where('transaction_id', 'txn-1')->value('consumed_at'));
    }

    public function test_retried_callback_is_stored_once(): void
    {
        $user = User::factory()->create();

        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-1'))->assertOk();
        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-1'))->assertOk();

        $this->assertSame(1, AdReward::count());
    }

    public function test_tampered_callback_is_rejected(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $query = str_replace($user->id, $other->id, $this->signedQuery($user, 'txn-1'));

        $this->get('/api/v1/admob/ssv?'.$query)->assertForbidden();
        $this->assertSame(0, AdReward::count());
    }

    public function test_callback_from_a_foreign_ad_unit_unlocks_nothing(): void
    {
        $user = User::factory()->create();

        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-1', adUnit: '9999999999'))->assertOk();

        $this->assertSame(0, AdReward::count());
    }

    public function test_view_older_than_an_hour_does_not_count(): void
    {
        $user = User::factory()->create();
        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-1'))->assertOk();
        $this->travel(61)->minutes();

        Sanctum::actingAs($user);
        $this->postJson('/api/v1/wallet/bonus/claim')->assertStatus(409);
    }

    public function test_test_ad_view_endpoint_is_off_by_default(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/wallet/bonus/test-ad-view')->assertNotFound();
    }

    public function test_bonus_needs_no_ad_when_not_required(): void
    {
        AdmobSetting::query()->update(['bonus_requires_ad' => false]);
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/wallet')->assertOk()->assertJsonPath('data.bonus_requires_ad', false);
        $this->postJson('/api/v1/wallet/bonus/claim')->assertOk();
    }

    /** A callback as AdMob sends it: signed params, then signature and key_id last. */
    private function signedQuery(User $user, string $transactionId, string $adUnit = self::AD_UNIT): string
    {
        $message = http_build_query([
            'ad_network' => '5450213213286189855',
            'ad_unit' => $adUnit,
            'reward_amount' => 1,
            'reward_item' => 'Reward',
            'timestamp' => now()->getTimestampMs(),
            'transaction_id' => $transactionId,
            'user_id' => $user->id,
        ]);
        openssl_sign($message, $signature, $this->privateKey, OPENSSL_ALGO_SHA256);

        return $message.'&signature='.rtrim(strtr(base64_encode($signature), '+/', '-_'), '=').'&key_id='.self::KEY_ID;
    }
}
