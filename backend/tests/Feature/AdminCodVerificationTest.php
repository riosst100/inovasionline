<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\CodVerification;
use App\Models\Role;
use App\Models\User;
use App\Services\CodVerificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCodVerificationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    public function test_events_can_be_filtered_by_customer_and_id(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        [$alice, $bob] = User::factory()->count(2)->create();

        // Alice re-verified after a revoke: both events stay listed.
        $first = $this->verify($alice);
        app(CodVerificationService::class)->revoke($first, 'Wajah tidak sesuai');
        $this->verify($alice);
        $this->verify($bob);

        $this->getJson('/api/admin/cod-verifications')->assertSuccessful()->assertJsonCount(3, 'data');

        $res = $this->getJson("/api/admin/cod-verifications?user_id={$alice->id}")->assertSuccessful();
        $res->assertJsonCount(2, 'data');
        $this->assertSame([$alice->id], collect($res->json('data'))->pluck('user_id')->unique()->values()->all());

        $this->getJson("/api/admin/cod-verifications?id={$first->id}")
            ->assertSuccessful()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.revoked_reason', 'Wajah tidak sesuai');
    }

    public function test_status_lives_on_the_user_and_points_at_the_event(): void
    {
        $user = User::factory()->create();
        $service = app(CodVerificationService::class);

        $this->assertNull($service->current($user));

        $event = $this->verify($user);
        $user->refresh();
        $this->assertSame('verified', $user->verification_status);
        $this->assertSame($event->id, $user->verification_id);
        $this->assertTrue($service->current($user)->is($event));
    }

    public function test_revoke_from_event_updates_user(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $user = User::factory()->create();
        $event = $this->verify($user);

        $this->postJson("/api/admin/cod-verifications/{$event->id}/revoke", ['reason' => 'Rekaman palsu'])
            ->assertSuccessful()
            ->assertJsonPath('data.status', 'revoked');

        $user->refresh();
        $this->assertSame('revoked', $user->verification_status);
        $this->assertSame($event->id, $user->verification_id);
        $this->assertNull(app(CodVerificationService::class)->current($user));
    }

    public function test_revoke_from_customer_list_revokes_the_active_event(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $user = User::factory()->create();
        $old = $this->verify($user);
        app(CodVerificationService::class)->revoke($old, 'Lama');
        $active = $this->verify($user);

        $this->postJson("/api/admin/customers/{$user->id}/revoke-verification", ['reason' => 'Dilaporkan kurir'])
            ->assertSuccessful()
            ->assertJsonPath('data.verification_status', 'revoked')
            ->assertJsonPath('data.verification_id', $active->id);

        $this->assertSame('Dilaporkan kurir', $active->fresh()->revoked_reason);
        $this->assertSame('Lama', $old->fresh()->revoked_reason);

        // Nothing left to revoke.
        $this->postJson("/api/admin/customers/{$user->id}/revoke-verification", ['reason' => 'Lagi'])
            ->assertUnprocessable();
    }

    private function verify(User $user): CodVerification
    {
        return app(CodVerificationService::class)->submit(
            $user->fresh(),
            UploadedFile::fake()->create('face.mp4', 100, 'video/mp4'),
            CodVerificationService::REQUIRED_STEPS,
            'Pixel 8',
            '127.0.0.1',
        );
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
