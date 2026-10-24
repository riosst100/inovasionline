<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminUsernameLoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_logs_in_with_username(): void
    {
        $admin = $this->admin();
        $this->assertSame('admin', $admin->username);

        $this->postJson('/api/admin/auth/login', ['username' => 'Admin', 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('data.user.username', 'admin')
            ->assertJsonPath('data.user.email', 'admin@example.com');

        $this->postJson('/api/admin/auth/login', ['username' => 'admin', 'password' => 'wrong'])
            ->assertStatus(422);
        $this->postJson('/api/admin/auth/login', ['password' => 'secret123'])
            ->assertStatus(422);
    }

    public function test_generated_usernames_stay_unique(): void
    {
        $admin = $this->admin();
        $driver = AdminUser::create([
            'name' => 'Driver',
            'email' => 'admin@other.test',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => $admin->role_id,
        ]);

        $this->assertSame('admin2', $driver->username);
    }

    public function test_staff_is_created_with_username_and_email(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin, ['admin']);

        $this->postJson('/api/admin/staff', [
            'name' => 'Kasir',
            'username' => 'kasir.satu',
            'email' => 'kasir@example.com',
            'password' => 'secret123',
            'role_id' => $admin->role_id,
        ])->assertCreated()->assertJsonPath('data.username', 'kasir.satu');

        $this->postJson('/api/admin/staff', [
            'name' => 'Kasir 2',
            'username' => 'kasir.satu',
            'email' => 'kasir2@example.com',
            'password' => 'secret123',
            'role_id' => $admin->role_id,
        ])->assertStatus(422)->assertJsonValidationErrors('username');

        $this->postJson('/api/admin/staff', [
            'name' => 'Kasir 3',
            'username' => 'Kasir Tiga',
            'email' => 'kasir3@example.com',
            'password' => 'secret123',
            'role_id' => $admin->role_id,
        ])->assertStatus(422)->assertJsonValidationErrors('username');
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
