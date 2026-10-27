<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\OrderDeviceLog;
use App\Models\PaymentMethod;
use App\Models\ShippingMethod;
use App\Models\User;
use App\Services\CheckoutService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Mockery\MockInterface;
use Tests\TestCase;

/** Checkout freezes the device, IP and position an order was placed from. */
class OrderDeviceLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_checkout_records_device_ip_and_location(): void
    {
        $user = User::factory()->create();
        $this->fakeCheckout($user);
        Sanctum::actingAs($user);

        $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7', 'HTTP_USER_AGENT' => 'Dart/3.13 (dart:io)'])
            ->postJson('/api/v1/checkout', [
                ...$this->payload(),
                'install_id' => str_repeat('d', 32),
                'app_version' => '1.0.1',
                'build_number' => 8,
                'device' => [
                    'id' => 'a1b2c3d4e5f60718',
                    'name' => 'Galaxy A15',
                    'brand' => 'samsung',
                    'model' => 'samsung SM-A155F',
                    'os_version' => 'Android 14 (SDK 34)',
                    'is_emulator' => true,
                    'details' => ['build_tags' => 'test-keys'],
                ],
                'location' => ['latitude' => -6.2, 'longitude' => 106.816666, 'accuracy' => 12.5, 'at' => '2026-10-26T10:00:00+07:00'],
            ])->assertCreated();

        $log = OrderDeviceLog::sole();
        $this->assertSame($user->id, $log->user_id);
        $this->assertSame('a1b2c3d4e5f60718', $log->device_id);
        $this->assertTrue($log->is_emulator);
        $this->assertSame(['build_tags' => 'test-keys'], $log->device_details);
        $this->assertSame(8, $log->build_number);
        $this->assertSame('203.0.113.7', $log->ip_address);
        $this->assertSame('Dart/3.13 (dart:io)', $log->user_agent);
        $this->assertSame(-6.2, $log->latitude);
        $this->assertSame(12.5, $log->location_accuracy);
    }

    public function test_older_app_without_device_still_logs_ip(): void
    {
        $user = User::factory()->create();
        $this->fakeCheckout($user);
        Sanctum::actingAs($user);

        $this->withServerVariables(['REMOTE_ADDR' => '198.51.100.9'])
            ->postJson('/api/v1/checkout', $this->payload())
            ->assertCreated();

        $log = OrderDeviceLog::sole();
        $this->assertNull($log->device_id);
        $this->assertNull($log->latitude);
        $this->assertSame('198.51.100.9', $log->ip_address);
    }

    /** The order itself is CheckoutService's job; here it only has to exist. */
    private function fakeCheckout(User $user): void
    {
        $order = Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => $user->id,
            'grand_total' => 10000,
            'status' => OrderStatus::PROCESSING,
            'payment_status' => PaymentStatus::UNPAID,
        ]);
        $this->mock(CheckoutService::class, fn (MockInterface $mock) => $mock->shouldReceive('checkout')->andReturn($order));
    }

    private function payload(): array
    {
        DB::table('indonesia_provinces')->insertOrIgnore(['code' => '11', 'name' => 'ACEH']);
        DB::table('indonesia_cities')->insertOrIgnore(['code' => '1101', 'province_code' => '11', 'name' => 'KAB. SIMEULUE']);
        DB::table('indonesia_districts')->insertOrIgnore(['code' => '1101010', 'city_code' => '1101', 'name' => 'TEUPAH SELATAN']);
        DB::table('indonesia_villages')->insertOrIgnore(['code' => '1101010001', 'district_code' => '1101010', 'name' => 'LATIUNG']);

        return [
            'payment_method_id' => PaymentMethod::query()->firstOrFail()->id,
            'shipping_method_id' => ShippingMethod::query()->where('type', 'io_express')->firstOrFail()->id,
            'recipient_name' => 'Pembeli Uji',
            'recipient_phone' => '081200000000',
            'province_code' => '11',
            'city_code' => '1101',
            'district_code' => '1101010',
            'village_code' => '1101010001',
            'address_detail' => 'Jl. Contoh No. 1',
        ];
    }
}
