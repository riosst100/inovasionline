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
use Illuminate\Support\Facades\Http;
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

    public function test_route_to_the_checkout_location_is_fetched_once_and_trimmed_as_the_courier_moves(): void
    {
        config(['services.openrouteservice.key' => 'test-key']);
        Http::fake(['api.openrouteservice.org/*' => Http::response([
            'features' => [[
                // [lng, lat]: three points ~1.1 km apart going north.
                'geometry' => ['coordinates' => [[106.8, -6.2], [106.8, -6.19], [106.8, -6.18]]],
                'properties' => ['summary' => ['distance' => 2200, 'duration' => 600]],
            ]],
        ])]);

        $driver = $this->driver();
        $driver->forceFill(['last_latitude' => -6.2, 'last_longitude' => 106.8, 'last_location_at' => now()])->save();
        $buyer = User::factory()->create();
        $order = $this->order($buyer, OrderStatus::ON_DELIVERY, $driver);
        $order->deviceLog()->create(['user_id' => $buyer->id, 'latitude' => -6.18, 'longitude' => 106.8]);

        $this->actingAs($buyer)->getJson("/api/v1/orders/{$order->id}/tracking")
            ->assertOk()
            ->assertJsonPath('data.destination.latitude', -6.18)
            ->assertJsonPath('data.route.distance_m', 2200)
            ->assertJsonPath('data.route.points.0', [-6.2, 106.8])
            ->assertJsonCount(3, 'data.route.points');

        // The courier reached the middle point: the cached route is reused, minus the driven half.
        $driver->forceFill(['last_latitude' => -6.19])->save();
        $this->actingAs($buyer)->getJson("/api/v1/orders/{$order->id}/tracking")
            ->assertJsonPath('data.route.distance_m', 1100)
            ->assertJsonPath('data.route.duration_s', 300)
            ->assertJsonCount(2, 'data.route.points');

        Http::assertSentCount(1);
    }

    public function test_without_a_route_key_the_app_gets_no_route(): void
    {
        config(['services.openrouteservice.key' => null]);
        Http::fake();
        $driver = $this->driver();
        $driver->forceFill(['last_latitude' => -6.2, 'last_longitude' => 106.8, 'last_location_at' => now()])->save();
        $buyer = User::factory()->create();
        $order = $this->order($buyer, OrderStatus::ON_DELIVERY, $driver);
        $order->deviceLog()->create(['user_id' => $buyer->id, 'latitude' => -6.18, 'longitude' => 106.8]);

        $this->actingAs($buyer)->getJson("/api/v1/orders/{$order->id}/tracking")
            ->assertJsonPath('data.destination.latitude', -6.18)
            ->assertJsonPath('data.route', null);

        Http::assertNothingSent();
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
