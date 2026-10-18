<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\OrderSetting;
use App\Models\Role;
use App\Models\User;
use App\Models\WalletTopup;
use App\Services\WalletService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderCancelWindowTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_cancel_processing_order_within_window_and_gets_refund(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(30));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled')
            ->assertJsonPath('data.payment_status', 'refunded');

        $this->assertSame(45000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_hold_freezes_countdown_so_a_slow_confirmation_still_cancels(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(50));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-hold")
            ->assertOk()
            ->assertJsonPath('data.cancel_on_hold', true)
            ->assertJsonPath('data.cancel_seconds_left', 10);

        // The buyer reads the terms for 40s, well past the original deadline.
        $this->travel(40)->seconds();

        $this->actingAs($user)->getJson("/api/v1/orders/{$order->id}")
            ->assertJsonPath('data.cancel_seconds_left', 10)
            ->assertJsonPath('data.can_cancel', true);

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertOk();
        $this->assertSame(45000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_backing_out_closes_cancelling_for_good(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(10));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-hold")->assertOk();

        // 50s of the window are still left, but backing out ends it.
        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-decline")
            ->assertOk()
            ->assertJsonPath('data.status', 'processing')
            ->assertJsonPath('data.cancel_on_hold', false)
            ->assertJsonPath('data.can_cancel', false);

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-hold")->assertStatus(422);
        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertStatus(422);
        $this->assertSame(OrderStatus::PROCESSING, $order->fresh()->status);
        $this->assertSame(0.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_abandoned_hold_counts_as_backing_out(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(10));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-hold")->assertOk();
        // App closed mid-dialog: the hold expires, even though the window had time left.
        $this->travel(Order::BUYER_CANCEL_MAX_HOLD_SECONDS + 1)->seconds();

        $this->actingAs($user)->getJson("/api/v1/orders/{$order->id}")
            ->assertJsonPath('data.cancel_on_hold', false)
            ->assertJsonPath('data.can_cancel', false);
        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertStatus(422);
    }

    public function test_hold_is_refused_after_window(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(61));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel-hold")->assertStatus(422);
        $this->assertNull($order->fresh()->cancel_hold_started_at);
    }

    public function test_buyer_cannot_cancel_after_window(): void
    {
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(61));

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertStatus(422);

        $this->assertSame(OrderStatus::PROCESSING, $order->fresh()->status);
        $this->assertSame(0.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_window_follows_admin_setting(): void
    {
        OrderSetting::create(['buyer_cancel_window_seconds' => 300]);
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now()->subSeconds(120));

        $this->actingAs($user)->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.can_cancel', true);

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertOk();
    }

    public function test_zero_window_disables_cancelling_processing_orders(): void
    {
        OrderSetting::create(['buyer_cancel_window_seconds' => 0]);
        $user = $this->userWithBalance(0);
        $order = $this->processingOrder($user, 45000, now());

        $this->actingAs($user)->postJson("/api/v1/orders/{$order->id}/cancel")->assertStatus(422);
    }

    public function test_admin_can_read_and_update_setting(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->getJson('/api/admin/order-settings')
            ->assertOk()
            ->assertJsonPath('data.buyer_cancel_window_seconds', 60);

        $this->putJson('/api/admin/order-settings', ['buyer_cancel_window_seconds' => 120])
            ->assertOk()
            ->assertJsonPath('data.buyer_cancel_window_seconds', 120);

        $this->putJson('/api/admin/order-settings', ['buyer_cancel_window_seconds' => -1])->assertStatus(422);

        $this->assertSame(120, OrderSetting::current()->buyer_cancel_window_seconds);
    }

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super-admin', 'is_system' => true])->id,
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

    /** A wallet-paid order that entered preparation at [$processingSince]. */
    private function processingOrder(User $user, float $total, \DateTimeInterface $processingSince): Order
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
            'status' => OrderStatus::PROCESSING,
            'payment_status' => PaymentStatus::PAID,
            'paid_at' => $processingSince,
            'delivery_method' => 'io_express',
            'status_history' => [
                ['status' => 'processing', 'at' => $processingSince->format(DATE_ATOM), 'by' => 'buyer'],
            ],
        ]);
    }
}
