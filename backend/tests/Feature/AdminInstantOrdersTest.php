<?php

namespace Tests\Feature;

use App\Events\AdminDataChanged;
use App\Models\AdminUser;
use App\Models\DeliverySchedule;
use App\Models\Order;
use App\Models\OrderSetting;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminInstantOrdersTest extends TestCase
{
    use RefreshDatabase;

    public function test_lists_unshipped_instant_orders_oldest_first_with_deadline(): void
    {
        OrderSetting::create(['buyer_cancel_window_seconds' => 60, 'instant_dispatch_minutes' => 20]);
        $user = User::factory()->create();

        $old = $this->order($user, OrderStatus::PROCESSING, now()->subMinutes(30));
        $new = $this->order($user, OrderStatus::PENDING, now()->subMinutes(5));
        $this->order($user, OrderStatus::ON_DELIVERY, now()->subMinutes(40));   // already shipped
        $this->order($user, OrderStatus::COMPLETED, now()->subMinutes(50));
        $this->order($user, OrderStatus::PROCESSING, now()->subMinutes(60), deliveryDate: now()->toDateString()); // scheduled

        Sanctum::actingAs($this->admin(['orders.view']), ['admin']);

        $res = $this->getJson('/api/admin/orders/instant')
            ->assertOk()
            ->assertJsonPath('data.dispatch_minutes', 20)
            ->assertJsonPath('data.count', 2)
            ->assertJsonPath('data.unpacked', 1)
            ->assertJsonPath('data.open', 4)
            ->assertJsonPath('data.orders.*.id', [$old->id, $new->id]);

        $this->assertTrue(
            Carbon::parse($res->json('data.orders.0.deadline_at'))->equalTo($old->created_at->copy()->addMinutes(20))
        );
    }

    public function test_scheduled_orders_per_slot_for_a_date(): void
    {
        $slot = DeliverySchedule::query()->where('is_active', true)->orderBy('start_time')->firstOrFail();
        $slot->update(['days' => null]);
        $user = User::factory()->create();
        $tomorrow = now('Asia/Jakarta')->addDay()->toDateString();

        $a = $this->order($user, OrderStatus::PROCESSING, now()->subHour(), deliveryDate: $tomorrow, scheduleId: $slot->id);
        $this->order($user, OrderStatus::CANCELLED, now(), deliveryDate: $tomorrow, scheduleId: $slot->id);
        $this->order($user, OrderStatus::PENDING, now(), deliveryDate: now('Asia/Jakarta')->toDateString(), scheduleId: $slot->id);

        Sanctum::actingAs($this->admin(['orders.view']), ['admin']);

        $res = $this->getJson("/api/admin/orders/scheduled?date={$tomorrow}")
            ->assertOk()
            ->assertJsonPath('data.date', $tomorrow)
            ->assertJsonPath('data.count', 1)
            ->assertJsonPath('data.orders.*.id', [$a->id]);

        $this->assertSame(1, collect($res->json('data.slots'))->firstWhere('id', $slot->id)['count']);
        $this->getJson('/api/admin/orders/scheduled')->assertOk()->assertJsonPath('data.count', 1);
    }

    public function test_order_changes_signal_admin_panels(): void
    {
        Event::fake([AdminDataChanged::class]);

        $this->order(User::factory()->create(), OrderStatus::PENDING, now());

        Event::assertDispatched(AdminDataChanged::class, function (AdminDataChanged $e) {
            $channels = collect($e->broadcastOn())->map->name->all();

            return $e->topic === AdminDataChanged::ORDERS
                && $channels === ['private-admin.dashboard', 'private-admin.orders'];
        });
    }

    public function test_needs_orders_permission(): void
    {
        Sanctum::actingAs($this->admin(['dashboard.view']), ['admin']);

        $this->getJson('/api/admin/orders/instant')->assertForbidden();
    }

    private function order(User $user, OrderStatus $status, Carbon $at, ?string $deliveryDate = null, ?string $scheduleId = null): Order
    {
        $order = Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => $user->id,
            'subtotal' => 10000,
            'discount_total' => 0,
            'shipping_fee' => 0,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => 10000,
            'status' => $status,
            'payment_status' => PaymentStatus::PAID,
            'delivery_method' => 'io_express',
            'delivery_date' => $deliveryDate,
            'delivery_schedule_id' => $scheduleId,
        ]);
        $order->forceFill(['created_at' => $at])->save();

        return $order->fresh();
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
