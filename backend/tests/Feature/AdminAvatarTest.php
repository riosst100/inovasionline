<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminAvatarTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_uploads_and_replaces_own_avatar(): void
    {
        Storage::fake('public');
        $admin = $this->admin();
        Sanctum::actingAs($admin, ['admin']);

        $this->post('/api/admin/auth/avatar', ['avatar' => UploadedFile::fake()->image('a.jpg')], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.id', $admin->id);

        $first = $admin->fresh()->avatar_path;
        Storage::disk('public')->assertExists($first);

        $res = $this->post('/api/admin/auth/avatar', ['avatar' => UploadedFile::fake()->image('b.png')], ['Accept' => 'application/json'])
            ->assertOk();

        $second = $admin->fresh()->avatar_path;
        $this->assertNotSame($first, $second);
        Storage::disk('public')->assertMissing($first);
        Storage::disk('public')->assertExists($second);
        $this->assertStringEndsWith($second, $res->json('data.avatar_url'));
    }

    public function test_avatar_must_be_an_image(): void
    {
        Storage::fake('public');
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->post('/api/admin/auth/avatar', ['avatar' => UploadedFile::fake()->create('a.pdf', 10, 'application/pdf')], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('avatar');
    }

    public function test_admin_removes_own_avatar(): void
    {
        Storage::fake('public');
        $admin = $this->admin();
        $path = UploadedFile::fake()->image('a.jpg')->store('admin-avatars', 'public');
        $admin->forceFill(['avatar_path' => $path])->save();
        Sanctum::actingAs($admin, ['admin']);

        $this->deleteJson('/api/admin/auth/avatar')
            ->assertOk()
            ->assertJsonPath('data.avatar_url', null);

        $this->assertNull($admin->fresh()->avatar_path);
        Storage::disk('public')->assertMissing($path);
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
