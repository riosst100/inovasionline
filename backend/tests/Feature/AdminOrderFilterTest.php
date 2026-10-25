<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Role;
use App\Models\ShippingMethod;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminOrderFilterTest extends TestCase
{
    use RefreshDatabase;

    public function test_filters_by_wib_date_shipping_method_and_total(): void
    {
        $express = ShippingMethod::query()->where('type', 'io_express')->firstOrFail();
        $sameDay = ShippingMethod::query()->where('type', 'io_same_day')->firstOrFail();
        $user = User::factory()->create();

        // 25 Oct 23:30 WIB = 25 Oct 16:30 UTC; 26 Oct 00:30 WIB = 25 Oct 17:30 UTC.
        $late25 = $this->order($user, Carbon::parse('2026-10-25 16:30:00', 'UTC'), $express, 50000);
        $early26 = $this->order($user, Carbon::parse('2026-10-25 17:30:00', 'UTC'), $sameDay, 150000, OrderStatus::COMPLETED);

        Sanctum::actingAs($this->admin(['orders.view']), ['admin']);

        $ids = fn (string $query) => collect($this->getJson("/api/admin/orders?{$query}")->assertOk()->json('data'))->pluck('id')->all();

        $this->assertSame([$late25->id], $ids('date_from=2026-10-25&date_to=2026-10-25'));
        $this->assertSame([$early26->id], $ids('date_from=2026-10-26'));
        $this->assertSame([$early26->id], $ids("shipping_method_id={$sameDay->id}"));
        $this->assertSame([$late25->id], $ids('total_max=100000'));
        $this->assertSame([$early26->id], $ids('total_min=100000'));

        // Tab counts follow the same filters.
        $this->getJson("/api/admin/orders/counts?shipping_method_id={$sameDay->id}")
            ->assertOk()
            ->assertJsonPath('data.all', 1)
            ->assertJsonPath('data.completed', 1)
            ->assertJsonPath('data.pending', 0);

        $this->getJson('/api/admin/orders?date_from=2026-10-26&date_to=2026-10-25')->assertUnprocessable();
    }

    public function test_orders_role_can_list_shipping_methods_for_the_filter(): void
    {
        Sanctum::actingAs($this->admin(['orders.view']), ['admin']);

        $this->getJson('/api/admin/shipping-methods')->assertOk();
        $this->postJson('/api/admin/shipping-methods', [])->assertForbidden();
    }

    private function order(User $user, Carbon $at, ShippingMethod $method, int $total, OrderStatus $status = OrderStatus::PENDING): Order
    {
        $order = Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => $user->id,
            'shipping_method_id' => $method->id,
            'subtotal' => $total,
            'discount_total' => 0,
            'shipping_fee' => 0,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => $total,
            'status' => $status,
            'payment_status' => PaymentStatus::PAID,
            'delivery_method' => $method->type,
        ]);
        $order->forceFill(['created_at' => $at])->save();

        return $order;
    }

    private function admin(array $permissions): AdminUser
    {
        return AdminUser::create([
            'name' => 'Staff',
            'email' => 'staff@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Staff', 'slug' => 'staff', 'permissions' => $permissions])->id,
        ]);
    }
}
