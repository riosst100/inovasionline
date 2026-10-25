<?php

namespace Tests\Feature;

use App\Models\AdChest;
use App\Models\AdChestSetting;
use App\Models\AdminUser;
use App\Models\AdmobSetting;
use App\Models\AdReward;
use App\Models\Role;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\AdmobSsvVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdChestTest extends TestCase
{
    use RefreshDatabase;

    private const KEY_ID = '1234567890';

    private const AD_UNIT = '5224354917';

    /** @var \OpenSSLAsymmetricKey */
    private $privateKey;

    private int $txn = 0;

    protected function setUp(): void
    {
        parent::setUp();

        $this->privateKey = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        $pem = openssl_pkey_get_details($this->privateKey)['key'];
        Http::fake([AdmobSsvVerifier::KEYS_URL => Http::response(['keys' => [['keyId' => (int) self::KEY_ID, 'pem' => $pem]]])]);

        AdmobSetting::create([
            'is_active' => true,
            'android_rewarded_id' => 'ca-app-pub-3940256099942544/'.self::AD_UNIT,
        ]);
        AdChestSetting::create([
            'is_active' => true,
            'chests_per_day' => 2,
            'daily_budget' => 0,
            'step' => 50,
            'tiers' => [['from' => 100, 'to' => 100, 'weight' => 100]],
        ]);
    }

    public function test_watching_one_ad_opens_a_chest_and_pays_saldo(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/wallet/chest')
            ->assertOk()
            ->assertJsonPath('data.opened_today', 0)
            ->assertJsonPath('data.chests_per_day', 2)
            ->assertJsonPath('data.max_amount', 100);

        // AdMob's callback has not landed yet: the app retries.
        $this->postJson('/api/v1/wallet/chest/open')
            ->assertStatus(409)
            ->assertJsonPath('errors.code.0', 'ad_view_required');

        $this->watch($user, 1);

        $this->postJson('/api/v1/wallet/chest/open')
            ->assertOk()
            ->assertJsonPath('data.claimed_amount', 100)
            ->assertJsonPath('data.chest.opened_today', 1);

        $this->assertEquals(100, $user->fresh()->wallet_balance);
        $this->assertSame(WalletTransaction::TYPE_AD_CHEST, WalletTransaction::where('user_id', $user->id)->value('type'));
        $this->assertSame(0, AdReward::whereNull('consumed_at')->count());

        // One view opens one chest only.
        $this->postJson('/api/v1/wallet/chest/open')->assertStatus(409);
    }

    public function test_bonus_views_do_not_open_chests_and_chest_views_do_not_unlock_the_bonus(): void
    {
        AdmobSetting::query()->update(['bonus_requires_ad' => true]);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'bonus-1', customData: null))->assertOk();
        $this->postJson('/api/v1/wallet/chest/open')->assertStatus(409);

        AdReward::query()->delete();
        $this->watch($user, 1);
        $this->postJson('/api/v1/wallet/bonus/claim')->assertStatus(409);
    }

    public function test_daily_chest_limit(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        foreach ([1, 2] as $_) {
            $this->watch($user, 1);
            $this->postJson('/api/v1/wallet/chest/open')->assertOk();
        }

        $this->getJson('/api/v1/wallet/chest')->assertJsonPath('data.done_today', true);
        $this->watch($user, 1);
        $this->postJson('/api/v1/wallet/chest/open')->assertStatus(422);
        $this->assertSame(2, AdChest::count());
    }

    public function test_chests_reset_at_midnight_wib(): void
    {
        $this->travelTo(now('Asia/Jakarta')->setTime(23, 0));
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        foreach ([1, 2] as $_) {
            $this->watch($user, 1);
            $this->postJson('/api/v1/wallet/chest/open')->assertOk();
        }
        $this->watch($user, 1);

        $this->travel(2)->hours();

        // Yesterday's unused view expired with the day.
        $this->getJson('/api/v1/wallet/chest')->assertJsonPath('data.opened_today', 0)->assertJsonPath('data.done_today', false);
        $this->postJson('/api/v1/wallet/chest/open')->assertStatus(409);
    }

    public function test_exhausted_budget_pays_the_smallest_prize_and_reports_sold_out(): void
    {
        AdChestSetting::query()->update([
            'daily_budget' => 150,
            'tiers' => [['from' => 50, 'to' => 50, 'weight' => 50], ['from' => 100, 'to' => 100, 'weight' => 50]],
        ]);
        AdChest::create(['user_id' => User::factory()->create()->id, 'amount' => 150]);

        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->watch($user, 1);

        $this->getJson('/api/v1/wallet/chest')->assertJsonPath('data.sold_out', true);
        $this->postJson('/api/v1/wallet/chest/open')->assertOk()->assertJsonPath('data.claimed_amount', 50);
    }

    public function test_chest_is_hidden_while_off_or_without_rewarded_ads(): void
    {
        Sanctum::actingAs(User::factory()->create());

        AdmobSetting::query()->update(['android_rewarded_id' => null]);
        $this->getJson('/api/v1/wallet/chest')->assertOk()->assertJsonPath('data', null);

        AdmobSetting::query()->update(['android_rewarded_id' => 'ca-app-pub-3940256099942544/'.self::AD_UNIT]);
        AdChestSetting::query()->update(['is_active' => false]);
        $this->getJson('/api/v1/wallet/chest')->assertJsonPath('data', null);
        $this->postJson('/api/v1/wallet/chest/open')->assertStatus(422);
    }

    public function test_admin_saves_settings(): void
    {
        $admin = AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super_admin', 'is_system' => true])->id,
        ]);
        Sanctum::actingAs($admin, ['admin']);

        $payload = [
            'is_active' => true,
            'chests_per_day' => 3,
            'daily_budget' => 50000,
            'step' => 50,
            'tiers' => [['from' => 50, 'to' => 100, 'weight' => 60], ['from' => 150, 'to' => 300, 'weight' => 30]],
        ];
        $this->putJson('/api/admin/ad-chest', $payload)->assertStatus(422)->assertJsonValidationErrors('tiers');

        $payload['tiers'][1]['weight'] = 40;
        $this->putJson('/api/admin/ad-chest', $payload)
            ->assertOk()
            ->assertJsonPath('data.chests_per_day', 3)
            ->assertJsonPath('data.ads_ready', true)
            ->assertJsonPath('data.paid_today', 0);
    }

    private function watch(User $user, int $views): void
    {
        for ($i = 0; $i < $views; $i++) {
            $this->get('/api/v1/admob/ssv?'.$this->signedQuery($user, 'txn-'.++$this->txn))->assertOk();
        }
    }

    /** A callback as AdMob sends it: signed params in its order, then signature and key_id. */
    private function signedQuery(User $user, string $transactionId, ?string $customData = 'chest'): string
    {
        $message = http_build_query(array_filter([
            'ad_network' => '5450213213286189855',
            'ad_unit' => self::AD_UNIT,
            'custom_data' => $customData,
            'reward_amount' => 1,
            'reward_item' => 'Reward',
            'timestamp' => now()->getTimestampMs(),
            'transaction_id' => $transactionId,
            'user_id' => $user->id,
        ], fn ($v) => $v !== null));
        openssl_sign($message, $signature, $this->privateKey, OPENSSL_ALGO_SHA256);

        return $message.'&signature='.rtrim(strtr(base64_encode($signature), '+/', '-_'), '=').'&key_id='.self::KEY_ID;
    }
}
