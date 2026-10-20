<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminOrderPackagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_order_ships_in_one_package_by_default(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        [$order, $rice, $oil] = $this->order();

        $this->getJson("/api/admin/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.packages_count', 1)
            ->assertJsonCount(1, 'data.packages')
            ->assertJsonPath('data.packages.0.items', [
                ['order_item_id' => $rice->id, 'quantity' => 3],
                ['order_item_id' => $oil->id, 'quantity' => 1],
            ]);
    }

    public function test_admin_splits_order_into_packages_with_own_qr(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        [$order, $rice, $oil] = $this->order();

        $response = $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [
            [['order_item_id' => $rice->id, 'quantity' => 2]],
            [['order_item_id' => $rice->id, 'quantity' => 1], ['order_item_id' => $oil->id, 'quantity' => 1]],
        ]])
            ->assertOk()
            ->assertJsonPath('data.packages_count', 2)
            ->assertJsonPath('data.packages.1.number', 2)
            ->assertJsonPath('data.packages.1.items.1', ['order_item_id' => $oil->id, 'quantity' => 1]);

        $first = $response->json('data.packages.0.qr_code');
        $second = $response->json('data.packages.1.qr_code');
        $this->assertNotSame($first, $second);

        // Every parcel QR, and the original order QR, resolve the order.
        $this->assertTrue(Order::findByQrCode($first)?->is($order));
        $this->assertTrue(Order::findByQrCode($second)?->is($order));
        $this->assertTrue(Order::findByQrCode($order->qrCode())?->is($order));
        $this->assertNull(Order::findByQrCode('IO:'.$order->order_number.':3:'.substr($second, -10)));

        // Back to one parcel: stored as the default, and parcel 2's label stops resolving.
        $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [[
            ['order_item_id' => $rice->id, 'quantity' => 3],
            ['order_item_id' => $oil->id, 'quantity' => 1],
        ]]])->assertOk()->assertJsonPath('data.packages_count', 1);

        $this->assertNull($order->fresh()->packages);
        $this->assertNull(Order::findByQrCode($second));
    }

    public function test_every_unit_must_be_packed_exactly_once(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        [$order, $rice, $oil] = $this->order();

        // Oil missing.
        $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [
            [['order_item_id' => $rice->id, 'quantity' => 2]],
            [['order_item_id' => $rice->id, 'quantity' => 1]],
        ]])->assertStatus(422);

        // Rice packed four times.
        $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [
            [['order_item_id' => $rice->id, 'quantity' => 3]],
            [['order_item_id' => $rice->id, 'quantity' => 1], ['order_item_id' => $oil->id, 'quantity' => 1]],
        ]])->assertStatus(422);

        // Empty parcel.
        $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [
            [['order_item_id' => $rice->id, 'quantity' => 3], ['order_item_id' => $oil->id, 'quantity' => 1]],
            [],
        ]])->assertStatus(422);

        $this->assertNull($order->fresh()->packages);
    }

    public function test_packages_are_locked_outside_processing(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        [$order, $rice, $oil] = $this->order(OrderStatus::READY);

        $this->putJson("/api/admin/orders/{$order->id}/packages", ['packages' => [
            [['order_item_id' => $rice->id, 'quantity' => 3]],
            [['order_item_id' => $oil->id, 'quantity' => 1]],
        ]])->assertStatus(422);
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

    /** @return array{Order, OrderItem, OrderItem} */
    private function order(OrderStatus $status = OrderStatus::PROCESSING): array
    {
        $order = Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => User::factory()->create()->id,
            'subtotal' => 95000,
            'discount_total' => 0,
            'shipping_fee' => 0,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => 95000,
            'status' => $status,
            'payment_status' => PaymentStatus::PAID,
            'paid_at' => now(),
            'delivery_method' => 'io_express',
            'status_history' => [
                ['status' => $status->value, 'at' => now()->toIso8601String(), 'by' => 'system'],
            ],
        ]);

        $rice = $order->items()->create([
            'product_name' => 'Beras 5kg', 'unit_price' => 25000, 'quantity' => 3, 'line_total' => 75000,
        ]);
        $oil = $order->items()->create([
            'product_name' => 'Minyak 2L', 'unit_price' => 20000, 'quantity' => 1, 'line_total' => 20000,
        ]);

        return [$order, $rice, $oil];
    }
}
