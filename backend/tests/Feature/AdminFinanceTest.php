<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Brand;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Role;
use App\Models\Supplier;
use App\Models\SupplierBill;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminFinanceTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_report_and_profit_match_the_sales_report_formula(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-10-15 03:00:00', 'UTC'));
        Sanctum::actingAs($this->admin(), ['admin']);
        $supplier = Supplier::create(['name' => 'CV Grosir']);
        $brand = Brand::create(['name' => 'Bimoli']);
        $oil = Product::create(['name' => 'Minyak', 'slug' => 'minyak', 'regular_price' => 10000, 'cost_price' => 7000, 'status' => 'active', 'supplier_id' => $supplier->id, 'brand_id' => $brand->id]);

        // 3 x oil (cost known) + 1 x unknown-cost item; 2000 discount, 5000 shipping, 1000 service fee.
        $order = $this->order(PaymentStatus::PAID, discount: 2000, shipping: 5000, serviceFee: 1000);
        $this->item($order, 10000, 3, $oil->id);
        $this->item($order, 4000, 1);
        // Unpaid order without items, and a cancelled one that never counts.
        $this->order(PaymentStatus::UNPAID, total: 20000);
        $this->order(PaymentStatus::UNPAID, total: 99000, status: OrderStatus::CANCELLED);

        $report = $this->getJson('/api/admin/finance/report?date_from=2026-10-01&date_to=2026-10-15')->assertOk();
        $report
            ->assertJsonPath('data.income_statement.product_sales', 34000)
            ->assertJsonPath('data.income_statement.net_sales', 32000)
            ->assertJsonPath('data.income_statement.cost', 21000)
            ->assertJsonPath('data.income_statement.gross_profit', 11000)
            ->assertJsonPath('data.income_statement.items_without_cost', 1)
            ->assertJsonPath('data.income_statement.gross_income', 17000)
            ->assertJsonPath('data.sales.orders', 2)
            ->assertJsonPath('data.sales.unpaid', 20000);

        // Same numbers as the dashboard's sales report.
        $this->getJson('/api/admin/sales-report?date_from=2026-10-01&date_to=2026-10-15')
            ->assertJsonPath('data.period.summary.gross_profit', 11000);

        $this->getJson('/api/admin/finance/profit?date_from=2026-10-01&date_to=2026-10-15&group=supplier')
            ->assertOk()
            ->assertJsonPath('data.rows.0.name', 'CV Grosir')
            ->assertJsonPath('data.rows.0.profit', 9000)
            ->assertJsonPath('data.rows.1.name', 'Tanpa supplier')
            ->assertJsonPath('data.rows.1.profit', null);

        $this->getJson('/api/admin/finance/profit?date_from=2026-10-01&date_to=2026-10-15&group=brand')
            ->assertJsonPath('data.rows.0.name', 'Bimoli')
            ->assertJsonPath('data.rows.0.margin', 30);
    }

    public function test_supplier_bills_lifecycle_and_summary(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-10-15 03:00:00', 'UTC'));
        Sanctum::actingAs($this->admin(), ['admin']);
        $supplier = Supplier::create(['name' => 'CV Grosir']);

        $overdueId = $this->postJson('/api/admin/supplier-bills', [
            'supplier_id' => $supplier->id, 'bill_number' => 'INV-1', 'bill_date' => '2026-10-01', 'due_date' => '2026-10-10', 'amount' => 500000,
        ])->assertCreated()->assertJsonPath('data.status', 'overdue')->json('data.id');

        $this->postJson('/api/admin/supplier-bills', [
            'supplier_id' => $supplier->id, 'bill_number' => 'INV-2', 'bill_date' => '2026-10-14', 'due_date' => '2026-10-20', 'amount' => 200000,
        ])->assertCreated()->assertJsonPath('data.status', 'unpaid');

        // Same number for the same supplier is rejected.
        $this->postJson('/api/admin/supplier-bills', [
            'supplier_id' => $supplier->id, 'bill_number' => 'INV-2', 'bill_date' => '2026-10-14', 'amount' => 1,
        ])->assertUnprocessable()->assertJsonValidationErrors('bill_number');

        $this->getJson('/api/admin/supplier-bills')
            ->assertOk()
            ->assertJsonPath('meta.summary.outstanding', 700000)
            ->assertJsonPath('meta.summary.overdue', 500000)
            ->assertJsonPath('meta.summary.due_soon', 200000);
        $this->getJson('/api/admin/supplier-bills?status=overdue')->assertJsonCount(1, 'data');

        $this->postJson("/api/admin/supplier-bills/{$overdueId}/pay", ['paid_date' => '2026-10-15', 'payment_notes' => 'Transfer BCA'])
            ->assertOk()
            ->assertJsonPath('data.status', 'paid');

        $this->deleteJson("/api/admin/supplier-bills/{$overdueId}")->assertUnprocessable();
        $this->deleteJson("/api/admin/suppliers/{$supplier->id}")->assertUnprocessable();

        $this->getJson('/api/admin/finance/report?date_from=2026-10-01&date_to=2026-10-15')
            ->assertJsonPath('data.supplier_bills.paid', 500000)
            ->assertJsonPath('data.supplier_bills.billed', 700000)
            ->assertJsonPath('data.supplier_bills.outstanding', 200000);

        $this->postJson("/api/admin/supplier-bills/{$overdueId}/unpay")->assertOk()->assertJsonPath('data.status', 'overdue');
        $this->assertNull(SupplierBill::find($overdueId)->paid_at);
    }

    private function order(
        PaymentStatus $payment,
        float $total = 0,
        float $discount = 0,
        float $shipping = 0,
        float $serviceFee = 0,
        OrderStatus $status = OrderStatus::COMPLETED,
    ): Order {
        return Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => User::factory()->create()->id,
            'subtotal' => $total,
            'discount_total' => $discount,
            'shipping_fee' => $shipping,
            'service_fee' => $serviceFee,
            'tax_total' => 0,
            'grand_total' => $total,
            'status' => $status,
            'payment_status' => $payment,
            'delivery_method' => 'io_express',
        ]);
    }

    private function item(Order $order, float $price, int $qty, ?string $productId = null): OrderItem
    {
        return OrderItem::create([
            'order_id' => $order->id,
            'product_id' => $productId,
            'product_name' => $productId ? Product::find($productId)->name : 'Gula 1kg',
            'unit_price' => $price,
            'quantity' => $qty,
            'discount_amount' => 0,
            'line_total' => $price * $qty,
        ]);
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
}
