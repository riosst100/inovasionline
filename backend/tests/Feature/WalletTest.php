<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Models\WalletBonusSetting;
use App\Models\WalletTopup;
use App\Models\WalletTransaction;
use App\Services\MidtransService;
use App\Services\OrderCancellationService;
use App\Services\WalletService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class WalletTest extends TestCase
{
    use RefreshDatabase;

    private const SERVER_KEY = 'SB-Mid-server-test';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.midtrans.server_key' => self::SERVER_KEY, 'services.wallet.max_balance' => 2000000]);
    }

    public function test_pay_debits_balance_and_writes_ledger(): void
    {
        $user = $this->userWithBalance(100000);
        $order = $this->order($user, 60000, PaymentStatus::UNPAID);

        app(WalletService::class)->payForOrder($order);

        $this->assertSame(40000.0, (float) $user->fresh()->wallet_balance);
        $this->assertDatabaseHas('wallet_transactions', ['order_id' => $order->id, 'type' => 'payment', 'amount' => -60000]);
    }

    public function test_pay_fails_without_enough_balance(): void
    {
        $user = $this->userWithBalance(10000);
        $order = $this->order($user, 60000, PaymentStatus::UNPAID);

        $this->expectException(RuntimeException::class);

        try {
            app(WalletService::class)->payForOrder($order);
        } finally {
            $this->assertSame(10000.0, (float) $user->fresh()->wallet_balance);
            $this->assertSame(0, WalletTransaction::count() - 1); // only the seed credit
        }
    }

    public function test_cancelling_a_paid_order_refunds_to_balance_once(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->order($user, 75000, PaymentStatus::PAID);

        app(OrderCancellationService::class)->cancel($order, 'buyer');
        app(WalletService::class)->refundOrder($order->fresh()); // second attempt is a no-op

        $order->refresh();
        $this->assertSame(OrderStatus::CANCELLED, $order->status);
        $this->assertSame(PaymentStatus::REFUNDED, $order->payment_status);
        $this->assertSame(75000.0, (float) $user->fresh()->wallet_balance);
        $this->assertSame(1, WalletTransaction::where('order_id', $order->id)->where('type', 'refund')->count());
    }

    public function test_cancelling_an_unpaid_order_does_not_touch_balance(): void
    {
        $user = $this->userWithBalance(5000);
        $order = $this->order($user, 75000, PaymentStatus::UNPAID);

        app(OrderCancellationService::class)->cancel($order, 'buyer');

        $this->assertSame(PaymentStatus::UNPAID, $order->fresh()->payment_status);
        $this->assertSame(5000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_topup_settlement_credits_balance_once(): void
    {
        $user = $this->userWithBalance(0);
        $topup = WalletTopup::create(['topup_number' => 'TOP-20261017-ABC123', 'user_id' => $user->id, 'amount' => 50000, 'payment_token' => 't']);

        $payload = $this->notification('TOP-20261017-ABC123', '50000.00', 'settlement');
        app(MidtransService::class)->handleNotification($payload);
        app(MidtransService::class)->handleNotification($payload); // Midtrans retries notifications

        $this->assertSame('paid', $topup->fresh()->status);
        $this->assertSame(50000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_topup_amount_mismatch_is_rejected(): void
    {
        $user = $this->userWithBalance(0);
        WalletTopup::create(['topup_number' => 'TOP-20261017-XYZ999', 'user_id' => $user->id, 'amount' => 50000, 'payment_token' => 't']);

        $this->expectException(RuntimeException::class);
        app(MidtransService::class)->handleNotification($this->notification('TOP-20261017-XYZ999', '5000000.00', 'settlement'));
    }

    public function test_payment_arriving_after_cancellation_is_refunded_to_balance(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->order($user, 30000, PaymentStatus::UNPAID, OrderStatus::CANCELLED);

        app(MidtransService::class)->handleNotification($this->notification($order->order_number, '30000.00', 'settlement'));
        // A retried notification must not refund twice.
        app(MidtransService::class)->handleNotification($this->notification($order->order_number, '30000.00', 'settlement'));

        $this->assertSame(PaymentStatus::REFUNDED, $order->fresh()->payment_status);
        $this->assertSame(OrderStatus::CANCELLED, $order->fresh()->status);
        $this->assertSame(30000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_settled_gateway_order_moves_to_processing(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->order($user, 30000, PaymentStatus::UNPAID, OrderStatus::PENDING);

        app(MidtransService::class)->handleNotification($this->notification($order->order_number, '30000.00', 'settlement'));

        $this->assertSame(OrderStatus::PROCESSING, $order->fresh()->status);
        $this->assertSame(PaymentStatus::PAID, $order->fresh()->payment_status);
    }

    public function test_bonus_can_be_claimed_once(): void
    {
        $user = $this->userWithBalance(0);

        $this->actingAs($user)->getJson('/api/v1/wallet')
            ->assertOk()
            ->assertJsonPath('data.bonus_available', true)
            ->assertJsonPath('data.bonus_max', 20000);

        $response = $this->actingAs($user)->postJson('/api/v1/wallet/bonus/claim')
            ->assertOk()
            ->assertJsonPath('data.bonus_available', false);
        $claimed = $response->json('data.claimed_amount');

        $this->assertGreaterThanOrEqual(1000, $claimed);
        $this->assertLessThanOrEqual(20000, $claimed);
        $this->assertEquals($claimed, $response->json('data.balance'));

        $this->actingAs($user)->postJson('/api/v1/wallet/bonus/claim')->assertStatus(422);

        $this->assertSame((float) $claimed, (float) $user->fresh()->wallet_balance);
        $this->assertSame(1, WalletTransaction::where('user_id', $user->id)->where('type', 'bonus')->count());
    }

    public function test_bonus_roll_stays_in_range_and_favours_low_amounts(): void
    {
        $wallet = app(WalletService::class);
        $counts = ['low' => 0, 'mid' => 0, 'high' => 0];

        for ($i = 0; $i < 2000; $i++) {
            $amount = $wallet->rollBonusAmount();
            $this->assertGreaterThanOrEqual(1000, $amount);
            $this->assertLessThanOrEqual(20000, $amount);
            $this->assertSame(0, $amount % 500);
            $counts[$amount <= 5000 ? 'low' : ($amount < 10000 ? 'mid' : 'high')]++;
        }

        // Expected 75% / 20% / 5% (1500 / 400 / 100); generous bounds keep this from flaking.
        $this->assertGreaterThan(1350, $counts['low']);
        $this->assertGreaterThan(250, $counts['mid']);
        $this->assertLessThan(550, $counts['mid']);
        $this->assertGreaterThan(30, $counts['high']);
        $this->assertLessThan(200, $counts['high']);
    }

    public function test_bonus_is_unavailable_when_disabled(): void
    {
        WalletBonusSetting::create(['is_active' => false, 'step' => 500, 'tiers' => WalletBonusSetting::DEFAULT_TIERS]);
        $user = $this->userWithBalance(0);

        $this->actingAs($user)->getJson('/api/v1/wallet')->assertJsonPath('data.bonus_available', false);
        $this->actingAs($user)->postJson('/api/v1/wallet/bonus/claim')->assertStatus(422);
        $this->assertSame(0.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_admin_sets_bonus_tiers_used_by_the_roll(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/wallet-bonus', [
            'is_active' => true,
            'step' => 1000,
            'tiers' => [['from' => 3000, 'to' => 3000, 'weight' => 100]],
        ])->assertOk()->assertJsonPath('data.tiers.0.from', 3000);

        $this->getJson('/api/admin/wallet-bonus')->assertOk()->assertJsonPath('data.step', 1000);
        $this->assertSame(3000, app(WalletService::class)->rollBonusAmount());
        $this->assertSame(3000, app(WalletService::class)->bonusMax());
    }

    public function test_admin_bonus_percentages_must_total_100(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->putJson('/api/admin/wallet-bonus', [
            'is_active' => true,
            'step' => 500,
            'tiers' => [['from' => 1000, 'to' => 5000, 'weight' => 60], ['from' => 5500, 'to' => 9500, 'weight' => 30]],
        ])->assertStatus(422);

        $this->assertSame(0, WalletBonusSetting::count());
    }

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super_admin', 'is_system' => true])->id,
        ]);
    }

    private function userWithBalance(float $amount): User
    {
        $user = User::factory()->create();

        if ($amount > 0) {
            $topup = WalletTopup::create(['topup_number' => 'TOP-SEED-'.$user->id, 'user_id' => $user->id, 'amount' => $amount]);
            app(WalletService::class)->creditTopup($topup);
        }

        return $user->fresh();
    }

    private function order(User $user, float $total, PaymentStatus $paymentStatus, OrderStatus $status = OrderStatus::PROCESSING): Order
    {
        return Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => $user->id,
            'subtotal' => $total,
            'discount_total' => 0,
            'shipping_fee' => 0,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => $total,
            'status' => $status,
            'payment_status' => $paymentStatus,
            'payment_token' => 'token',
            'delivery_method' => 'io_express',
            'status_history' => [],
        ]);
    }

    private function notification(string $orderId, string $grossAmount, string $status): array
    {
        $payload = [
            'order_id' => $orderId,
            'status_code' => '200',
            'gross_amount' => $grossAmount,
            'transaction_status' => $status,
            'transaction_id' => 'trx-'.uniqid(),
            'payment_type' => 'bank_transfer',
        ];
        $payload['signature_key'] = hash('sha512', $orderId.'200'.$grossAmount.self::SERVER_KEY);

        return $payload;
    }
}
