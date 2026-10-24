<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Employee;
use App\Models\Order;
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

class AdminCompanyTransactionTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_cash_book_combines_orders_bills_and_manual_entries(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-10-20 03:00:00', 'UTC'));
        Sanctum::actingAs($this->admin(), ['admin']);

        // 01:30 WIB on the 15th (still the 14th in UTC) counts on the 15th.
        $this->order(100000, PaymentStatus::PAID, '2026-10-14 18:30:00');
        $this->order(50000, PaymentStatus::UNPAID, null);
        // Paid before the period.
        $this->order(70000, PaymentStatus::PAID, '2026-10-14 16:00:00');

        $supplier = Supplier::create(['name' => 'CV Grosir']);
        SupplierBill::create([
            'supplier_id' => $supplier->id, 'bill_number' => 'INV-1', 'bill_date' => '2026-10-10',
            'amount' => 40000, 'paid_at' => Carbon::parse('2026-10-16 05:00:00', 'UTC'),
        ]);
        SupplierBill::create(['supplier_id' => $supplier->id, 'bill_number' => 'INV-2', 'bill_date' => '2026-10-10', 'amount' => 99000]);

        $employee = Employee::create(['name' => 'Budi', 'position' => 'Kurir', 'salary_type' => 'monthly', 'salary_amount' => 25000]);
        $salaryId = $this->postJson('/api/admin/company-transactions', [
            'type' => 'expense', 'category' => 'Gaji Karyawan', 'amount' => 25000,
            'transaction_date' => '2026-10-17', 'employee_id' => $employee->id,
        ])->assertCreated()->json('data.id');
        $this->postJson('/api/admin/company-transactions', [
            'type' => 'income', 'category' => 'Pemasukan Lain', 'amount' => 5000, 'transaction_date' => '2026-10-18',
        ])->assertCreated();

        $query = 'date_from=2026-10-15&date_to=2026-10-20';
        $res = $this->getJson("/api/admin/company-transactions?{$query}")->assertOk();
        $res->assertJsonPath('data.summary.income', 105000)
            ->assertJsonPath('data.summary.expense', 65000)
            ->assertJsonPath('data.summary.net', 40000)
            ->assertJsonCount(4, 'data.entries')
            // Newest first.
            ->assertJsonPath('data.entries.0.category', 'Pemasukan Lain')
            ->assertJsonPath('data.entries.1.employee_name', 'Budi')
            ->assertJsonPath('data.entries.2.source', 'supplier_bill')
            ->assertJsonPath('data.entries.3.source', 'order')
            ->assertJsonPath('data.entries.3.date', '2026-10-15');
        $this->assertContains('Gaji Karyawan', $res->json('data.categories.expense'));

        $this->getJson("/api/admin/company-transactions?{$query}&source=manual")->assertJsonCount(2, 'data.entries');
        $this->getJson("/api/admin/company-transactions?{$query}&type=expense")->assertJsonCount(2, 'data.entries');

        // Laporan Keuangan picks up the manual entries for net income.
        $this->getJson("/api/admin/finance/report?{$query}")
            ->assertJsonPath('data.income_statement.operating_expenses', 25000)
            ->assertJsonPath('data.income_statement.other_income', 5000);

        $this->putJson("/api/admin/company-transactions/{$salaryId}", [
            'type' => 'expense', 'category' => 'Gaji Karyawan', 'amount' => 30000, 'transaction_date' => '2026-10-17',
        ])->assertOk()->assertJsonPath('data.employee_id', null);
        $this->deleteJson("/api/admin/company-transactions/{$salaryId}")->assertOk();
        $this->getJson("/api/admin/company-transactions?{$query}")->assertJsonPath('data.summary.expense', 40000);
    }

    private function order(float $total, PaymentStatus $payment, ?string $paidAtUtc): Order
    {
        return Order::create([
            'order_number' => 'ORD-TEST-'.uniqid(),
            'user_id' => User::factory()->create()->id,
            'subtotal' => $total,
            'grand_total' => $total,
            'status' => OrderStatus::COMPLETED,
            'payment_status' => $payment,
            'paid_at' => $paidAtUtc ? Carbon::parse($paidAtUtc, 'UTC') : null,
            'delivery_method' => 'io_express',
        ]);
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
}
