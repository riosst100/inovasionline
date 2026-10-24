<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserContact;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserContactSyncTest extends TestCase
{
    use RefreshDatabase;

    private const INSTALL_ID = 'aaaaaaaaaaaaaaaa1111';

    public function test_guest_contacts_are_stored_normalized_and_deduplicated(): void
    {
        $this->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => [
                ['name' => 'Budi', 'phone' => '0812-3456-789'],
                ['name' => 'Budi Kantor', 'phone' => '+62 812 3456 789'],
                ['name' => 'Kode', 'phone' => '123'],
                ['name' => null, 'phone' => '08571234567'],
            ],
        ])->assertOk()->assertJsonPath('data.synced', 2);

        $this->assertSame(
            ['628123456789', '628571234567'],
            UserContact::query()->orderBy('phone')->pluck('phone')->all(),
        );
        $this->assertSame(0, UserContact::query()->whereNotNull('user_id')->count());
    }

    public function test_login_claims_contacts_uploaded_as_guest(): void
    {
        $this->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => [['name' => 'Budi', 'phone' => '08123456789']],
        ])->assertOk();

        $user = User::factory()->create();
        $this->actingAs($user)->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => [],
        ])->assertOk();

        $this->assertSame(1, $user->contacts()->count());
    }

    public function test_guest_resync_keeps_the_owner_and_matches_registered_users(): void
    {
        $owner = User::factory()->create();
        $friend = User::factory()->create(['phone' => '628123456789']);

        $this->actingAs($owner)->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => [['name' => 'Teman', 'phone' => '08123456789']],
        ])->assertOk();

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => [['name' => 'Teman Baru', 'phone' => '08123456789']],
        ])->assertOk();

        $contact = UserContact::query()->sole();
        $this->assertSame($owner->id, $contact->user_id);
        $this->assertSame('Teman Baru', $contact->name);
        $this->assertTrue($contact->matchedUser->is($friend));
    }

    public function test_rejects_oversized_chunks(): void
    {
        $this->postJson('/api/v1/contacts/sync', [
            'install_id' => self::INSTALL_ID,
            'contacts' => array_fill(0, 501, ['phone' => '08123456789']),
        ])->assertUnprocessable();
    }
}
