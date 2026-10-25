<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminOrderStatusTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_moves_order_through_its_stages(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin, ['admin']);
        $order = $this->order(User::factory()->create(), OrderStatus::PROCESSING, PaymentStatus::PAID);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'ready'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ready');

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'completed'])->assertStatus(422);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'on_delivery'])
            ->assertOk()
            ->assertJsonPath('data.status', 'on_delivery');

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'cancelled'])->assertStatus(422);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'completed', 'admin_notes' => 'Diterima tetangga'])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.admin_notes', 'Diterima tetangga');

        $order->refresh();
        $this->assertNotNull($order->completed_at);
        $this->assertSame(['processing', 'ready', 'on_delivery', 'completed'], array_column($order->status_history, 'status'));
        $this->assertSame('admin:'.$admin->id, last($order->status_history)['by']);
    }

    public function test_store_pickup_order_skips_delivery(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $order = $this->order(User::factory()->create(), OrderStatus::READY, PaymentStatus::PAID);
        $order->update(['delivery_method' => 'store_pickup']);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'on_delivery'])->assertStatus(422);
        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'completed'])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');
    }

    public function test_invalid_transition_is_refused(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $order = $this->order(User::factory()->create(), OrderStatus::PROCESSING, PaymentStatus::PAID);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'completed'])->assertStatus(422);
        $this->assertSame(OrderStatus::PROCESSING, $order->fresh()->status);
    }

    public function test_admin_cancel_refunds_paid_order_to_wallet(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $user = User::factory()->create();
        $order = $this->order($user, OrderStatus::PROCESSING, PaymentStatus::PAID, 30000);

        $this->patchJson("/api/admin/orders/{$order->id}/status", ['status' => 'cancelled'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled')
            ->assertJsonPath('data.payment_status', 'refunded');

        $this->assertSame(30000.0, (float) $user->fresh()->wallet_balance);
    }

    public function test_orders_can_be_searched_by_number_or_buyer(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $budi = User::factory()->create(['name' => 'Budi Santoso']);
        $this->order($budi, OrderStatus::PROCESSING, PaymentStatus::PAID);
        $other = $this->order(User::factory()->create(['name' => 'Siti']), OrderStatus::READY, PaymentStatus::PAID);

        $this->getJson('/api/admin/orders?search=budi')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user.name', 'Budi Santoso');
        $this->getJson('/api/admin/orders?search='.$other->order_number)->assertJsonCount(1, 'data');
        $this->getJson('/api/admin/orders?status=ready')->assertJsonCount(1, 'data');
    }

    public function test_mobile_login_returns_bearer_token(): void
    {
        $admin = $this->admin();

        $token = $this->withHeader('X-Client', 'mobile')
            ->postJson('/api/admin/auth/login', ['email' => $admin->email, 'password' => 'secret123'])
            ->assertOk()
            ->assertCookieMissing('admin_session')
            ->json('data.token');

        $this->assertNotEmpty($token);

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/admin/auth/me')->assertOk()
            ->assertJsonPath('data.email', $admin->email);
    }

    public function test_web_login_keeps_token_out_of_body(): void
    {
        $admin = $this->admin();

        $this->postJson('/api/admin/auth/login', ['email' => $admin->email, 'password' => 'secret123'])
            ->assertOk()
            ->assertCookie('admin_session')
            ->assertJsonMissingPath('data.token');
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

    private function order(User $user, OrderStatus $status, PaymentStatus $payment, float $total = 45000): Order
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
            'payment_status' => $payment,
            'paid_at' => now(),
            'delivery_method' => 'io_express',
            'status_history' => [
                ['status' => $status->value, 'at' => now()->toIso8601String(), 'by' => 'system'],
            ],
        ]);
    }
}
