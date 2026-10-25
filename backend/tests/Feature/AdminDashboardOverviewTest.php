<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Product;
use App\Models\Role;
use App\Models\Supplier;
use App\Models\SupplierBill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminDashboardOverviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_sees_every_section(): void
    {
        Sanctum::actingAs($this->admin(['*']), ['admin']);

        $this->getJson('/api/admin/dashboard/overview')
            ->assertOk()
            ->assertJsonPath('data.sections.*.title', ['Operasional', 'Perusahaan']);
    }

    public function test_cards_follow_menu_permissions(): void
    {
        $supplier = Supplier::create(['name' => 'PT Maju']);
        SupplierBill::create([
            'supplier_id' => $supplier->id, 'bill_number' => 'INV-1', 'bill_date' => now()->subDays(40)->toDateString(),
            'due_date' => now()->subDays(10)->toDateString(), 'amount' => 500000,
        ]);
        Product::create(['name' => 'Gula', 'slug' => 'gula', 'regular_price' => 15000, 'status' => 'active']);

        Sanctum::actingAs($this->admin(['dashboard.view', 'product_stocks.view', 'purchases.view']), ['admin']);

        $sections = collect($this->getJson('/api/admin/dashboard/overview')->assertOk()->json('data.sections'))->keyBy('title');

        $this->assertSame(['Operasional', 'Perusahaan'], $sections->keys()->all());
        $this->assertSame(['product_stocks'], collect($sections['Operasional']['cards'])->pluck('menu')->unique()->values()->all());

        $out = collect($sections['Operasional']['cards'])->firstWhere('label', 'Stok habis');
        $this->assertSame(1, $out['value']);
        $this->assertTrue($out['alert']);

        $overdue = collect($sections['Perusahaan']['cards'])->firstWhere('label', 'Lewat jatuh tempo');
        $this->assertEquals(500000, $overdue['value']);
        $this->assertTrue($overdue['alert']);
    }

    public function test_needs_dashboard_permission(): void
    {
        Sanctum::actingAs($this->admin(['orders.view']), ['admin']);

        $this->getJson('/api/admin/dashboard/overview')->assertForbidden();
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
