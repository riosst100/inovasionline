<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminEmployeeTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_manage_employees(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $id = $this->postJson('/api/admin/employees', [
            'name' => 'Budi', 'position' => 'Kurir', 'salary_type' => 'per_delivery', 'salary_amount' => 5000,
        ])->assertCreated()->json('data.id');
        $this->postJson('/api/admin/employees', [
            'name' => 'Sari', 'position' => 'Admin Gudang', 'salary_type' => 'monthly', 'salary_amount' => 3000000,
        ])->assertCreated();

        $this->postJson('/api/admin/employees', [
            'name' => 'X', 'position' => 'Kurir', 'salary_type' => 'per_jam', 'salary_amount' => 1,
        ])->assertUnprocessable()->assertJsonValidationErrors('salary_type');

        $this->getJson('/api/admin/employees')
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.positions', ['Admin Gudang', 'Kurir'])
            ->assertJsonPath('data.summary.active', 2)
            ->assertJsonPath('data.summary.monthly_total', 3000000);

        $this->putJson("/api/admin/employees/{$id}", [
            'name' => 'Budi', 'position' => 'Kurir', 'salary_type' => 'per_order', 'salary_amount' => 7000, 'is_active' => false,
        ])->assertOk()->assertJsonPath('data.salary_type', 'per_order')->assertJsonPath('data.is_active', false);

        $this->deleteJson("/api/admin/employees/{$id}")->assertOk();
        $this->assertDatabaseMissing('employees', ['id' => $id]);
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
