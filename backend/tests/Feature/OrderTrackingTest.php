<?php

namespace Tests\Feature;

use App\Events\OrderTrackingUpdated;
use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderTrackingTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_location_reaches_the_buyer_of_a_parcel_on_the_way(): void
    {
        Event::fake([OrderTrackingUpdated::class]);
        $driver = $this->driver();
        $buyer = User::factory()->create();
        $order = $this->order($buyer, OrderStatus::ON_DELIVERY, $driver);
        $other = $this->order(User::factory()->create(), OrderStatus::COMPLETED, $driver);

        Sanctum::actingAs($driver, ['*'], 'sanctum');
        $this->postJson('/api/admin/driver/location', ['latitude' => -6.2, 'longitude' => 106.816666, 'accuracy' => 12])
            ->assertOk();

        Event::assertDispatched(OrderTrackingUpdated::class, fn ($e) => $e->orderId === $order->id);
        Event::assertNotDispatched(OrderTrackingUpdated::class, fn ($e) => $e->orderId === $other->id);

        $this->actingAs($buyer)->getJson("/api/v1/orders/{$order->id}/tracking")
            ->assertOk()
            ->assertJsonPath('data.active', true)
            ->assertJsonPath('data.driver.name', 'Budi Kurir')
            ->assertJsonPath('data.location.latitude', -6.2)
            ->assertJsonPath('data.location.longitude', 106.816666);
    }

    public function test_courier_position_is_hidden_outside_delivery_and_from_other_buyers(): void
    {
        $driver = $this->driver();
        $driver->forceFill(['last_latitude' => -6.2, 'last_longitude' => 106.8, 'last_location_at' => now()])->save();
        $buyer = User::factory()->create();
        $delivered = $this->order($buyer, OrderStatus::COMPLETED, $driver);
        $onTheWay = $this->order($buyer, OrderStatus::ON_DELIVERY, $driver);

        $this->actingAs($buyer)->getJson("/api/v1/orders/{$delivered->id}/tracking")
            ->assertOk()
            ->assertJsonPath('data.active', false)
            ->assertJsonPath('data.driver', null)
            ->assertJsonPath('data.location', null);

        $this->actingAs(User::factory()->create())->getJson("/api/v1/orders/{$onTheWay->id}/tracking")
            ->assertForbidden();
    }

    public function test_only_drivers_can_report_a_location(): void
    {
        $staff = AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin-tracking@example.com',
            'password' => 'password',
            'role_id' => Role::create(['name' => 'Gudang', 'slug' => 'gudang', 'permissions' => ['orders.view']])->id,
            'is_active' => true,
        ]);

        Sanctum::actingAs($staff, ['*'], 'sanctum');
        $this->postJson('/api/admin/driver/location', ['latitude' => -6.2, 'longitude' => 106.8])->assertForbidden();
    }

    private function driver(): AdminUser
    {
        return AdminUser::create([
            'name' => 'Budi Kurir',
            'email' => 'kurir-tracking@example.com',
            'phone' => '081234567890',
            'password' => 'password',
            'role_id' => Role::driver()->id,
            'is_active' => true,
        ]);
    }

    private function order(User $buyer, OrderStatus $status, AdminUser $driver): Order
    {
        return Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => $buyer->id,
            'driver_id' => $driver->id,
            'subtotal' => 10000,
            'discount_total' => 0,
            'shipping_fee' => 0,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => 10000,
            'status' => $status,
            'payment_status' => PaymentStatus::PAID,
            'delivery_method' => 'io_express',
            'status_history' => [],
        ]);
    }
}
