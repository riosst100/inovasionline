<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use App\Models\Supplier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminMenuPermissionTest extends TestCase
{
    use RefreshDatabase;

    public function test_menu_without_permission_is_forbidden(): void
    {
        Sanctum::actingAs($this->staff(['orders.view']), ['admin']);

        $this->getJson('/api/admin/orders')->assertOk();
        $this->getJson('/api/admin/employees')->assertForbidden();
        $this->getJson('/api/admin/finance/report')->assertForbidden();
    }

    public function test_view_reads_but_cannot_write(): void
    {
        Sanctum::actingAs($this->staff(['suppliers.view']), ['admin']);

        $this->getJson('/api/admin/suppliers')->assertOk();
        $this->postJson('/api/admin/suppliers', ['name' => 'PT Maju'])->assertForbidden();
    }

    public function test_manage_writes(): void
    {
        Sanctum::actingAs($this->staff(['suppliers.manage']), ['admin']);

        $this->getJson('/api/admin/suppliers')->assertOk();
        $this->postJson('/api/admin/suppliers', ['name' => 'PT Maju'])->assertCreated();
    }

    public function test_page_using_a_lookup_can_read_it_but_not_change_it(): void
    {
        $supplier = Supplier::create(['name' => 'PT Maju']);
        Sanctum::actingAs($this->staff(['products.manage']), ['admin']);

        $this->getJson('/api/admin/suppliers')->assertOk();
        $this->putJson("/api/admin/suppliers/{$supplier->id}", ['name' => 'PT Mundur'])->assertForbidden();
    }

    public function test_data_transfers_follow_the_resource_menu(): void
    {
        Sanctum::actingAs($this->staff(['brands.view']), ['admin']);

        $this->getJson('/api/admin/data-transfers/template?resource=brands&format=csv')->assertOk();
        $this->getJson('/api/admin/data-transfers/template?resource=products&format=csv')->assertForbidden();
        $this->getJson('/api/admin/data-transfers')->assertOk();
    }

    public function test_role_rejects_unknown_permission_keys(): void
    {
        Sanctum::actingAs($this->staff(['roles.manage']), ['admin']);

        $this->postJson('/api/admin/roles', ['name' => 'Gudang', 'permissions' => ['products.view', 'catalog.manage']])
            ->assertUnprocessable();
        $this->postJson('/api/admin/roles', ['name' => 'Gudang', 'permissions' => ['products.view', 'products.manage']])
            ->assertCreated();
    }

    public function test_super_admin_passes_everywhere(): void
    {
        $role = Role::create(['name' => 'Super Admin', 'slug' => 'super_admin', 'is_system' => true]);
        Sanctum::actingAs($this->adminWithRole($role), ['admin']);

        $this->getJson('/api/admin/employees')->assertOk();
        $this->getJson('/api/admin/finance/report')->assertOk();
    }

    private function staff(array $permissions): AdminUser
    {
        return $this->adminWithRole(Role::create(['name' => 'Staff', 'slug' => 'staff', 'permissions' => $permissions]));
    }

    private function adminWithRole(Role $role): AdminUser
    {
        return AdminUser::create([
            'name' => 'Staff',
            'email' => 'staff@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => $role->id,
        ]);
    }
}
