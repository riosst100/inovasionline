<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminSalesReportTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_today_is_compared_with_yesterday_in_wib(): void
    {
        // 10:00 WIB on 15 Oct.
        Carbon::setTestNow(Carbon::parse('2026-10-15 03:00:00', 'UTC'));
        Sanctum::actingAs($this->admin(), ['admin']);
        $user = User::factory()->create();

        // 01:30 WIB today, though still the 14th in UTC.
        $this->order($user, 100000, '2026-10-14 18:30:00', OrderStatus::COMPLETED, PaymentStatus::PAID, 3);
        $this->order($user, 50000, '2026-10-15 02:00:00', OrderStatus::PENDING, PaymentStatus::UNPAID, 1);
        $this->order($user, 70000, '2026-10-15 02:30:00', OrderStatus::CANCELLED, PaymentStatus::REFUNDED, 5);
        // Yesterday (WIB).
        $this->order($user, 40000, '2026-10-14 05:00:00', OrderStatus::COMPLETED, PaymentStatus::PAID, 2);

        $res = $this->getJson('/api/admin/sales-report')
            ->assertOk()
            ->assertJsonPath('data.period.date_from', '2026-10-15')
            ->assertJsonPath('data.period.days', 1)
            ->assertJsonPath('data.period.summary.revenue', 150000)
            ->assertJsonPath('data.period.summary.revenue_paid', 100000)
            ->assertJsonPath('data.period.summary.orders', 2)
            ->assertJsonPath('data.period.summary.items_sold', 4)
            ->assertJsonPath('data.period.summary.cancelled', 1)
            ->assertJsonPath('data.previous.date_from', '2026-10-14')
            ->assertJsonPath('data.previous.summary.revenue', 40000)
            ->assertJsonPath('data.granularity', 'hour')
            ->assertJsonCount(24, 'data.series')
            ->assertJsonPath('data.series.1.revenue', 100000)
            ->assertJsonPath('data.series.9.revenue', 50000)
            ->assertJsonPath('data.series.12.previous_revenue', 40000)
            ->assertJsonPath('data.top_products.0.sold', 4)
            ->assertJsonPath('data.overall.revenue_total', 190000)
            ->assertJsonPath('data.overall.awaiting_payment', 1);

        $this->assertCount(3, $res->json('data.recent_orders'));
    }

    public function test_date_range_is_bucketed_per_day(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $user = User::factory()->create();
        $this->order($user, 20000, '2026-10-02 05:00:00');
        $this->order($user, 30000, '2026-09-30 05:00:00');

        $this->getJson('/api/admin/sales-report?date_from=2026-10-01&date_to=2026-10-03')
            ->assertOk()
            ->assertJsonPath('data.granularity', 'day')
            ->assertJsonCount(3, 'data.series')
            ->assertJsonPath('data.series.1.label', '2026-10-02')
            ->assertJsonPath('data.series.1.revenue', 20000)
            ->assertJsonPath('data.series.2.previous_revenue', 30000)
            ->assertJsonPath('data.previous.date_from', '2026-09-28')
            ->assertJsonPath('data.previous.date_to', '2026-09-30');

        $this->getJson('/api/admin/sales-report?date_from=2026-10-03&date_to=2026-10-01')->assertStatus(422);
    }

    public function test_gross_profit_uses_cost_snapshot_then_current_product_cost(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $productId = $this->postJson('/api/admin/products', [
            'name' => 'Minyak 1L',
            'regular_price' => 10000,
            'cost_price' => 2000,
            'status' => 'active',
        ])->assertSuccessful()->assertJsonPath('data.cost_price', '2000.00')->json('data.id');

        $this->assertArrayNotHasKey('cost_price', Product::find($productId)->toArray());

        // Snapshot 6000 x3, current product cost 2000 x1, unknown cost x2; 5000 order discount.
        $order = $this->order(User::factory()->create(), 48000, now()->toDateTimeString());
        $order->update(['discount_total' => 5000, 'grand_total' => 43000]);
        $order->items()->update(['unit_price' => 10000, 'quantity' => 3, 'line_total' => 30000, 'unit_cost' => 6000]);
        $this->item($order, 10000, 1, productId: $productId);
        $this->item($order, 4000, 2, name: 'Gula 1kg');

        $this->getJson('/api/admin/sales-report')
            ->assertOk()
            ->assertJsonPath('data.period.summary.product_sales', 43000)
            ->assertJsonPath('data.period.summary.cost', 20000)
            ->assertJsonPath('data.period.summary.gross_profit', 23000)
            ->assertJsonPath('data.period.summary.items_without_cost', 2)
            ->assertJsonPath('data.top_products.0.name', 'Beras 5kg')
            ->assertJsonPath('data.top_products.0.profit', 12000)
            ->assertJsonPath('data.top_products.1.name', 'Gula 1kg')
            ->assertJsonPath('data.top_products.1.profit', null)
            ->assertJsonPath('data.top_products.2.name', 'Minyak 1L')
            ->assertJsonPath('data.top_products.2.profit', 8000);
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

    private function order(
        User $user,
        float $total,
        string $createdAtUtc,
        OrderStatus $status = OrderStatus::COMPLETED,
        PaymentStatus $payment = PaymentStatus::PAID,
        int $qty = 1,
    ): Order {
        $order = Order::create([
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
            'delivery_method' => 'io_express',
        ]);
        $order->forceFill(['created_at' => Carbon::parse($createdAtUtc, 'UTC')])->save();

        $this->item($order, $total / $qty, $qty);

        return $order;
    }

    private function item(Order $order, float $price, int $qty, ?string $productId = null, string $name = 'Beras 5kg'): OrderItem
    {
        return OrderItem::create([
            'order_id' => $order->id,
            'product_id' => $productId,
            'product_name' => $productId ? Product::find($productId)->name : $name,
            'unit_price' => $price,
            'quantity' => $qty,
            'discount_amount' => 0,
            'line_total' => $price * $qty,
        ]);
    }
}
