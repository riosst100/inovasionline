<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\ChatThread;
use App\Models\CommunityRole;
use App\Models\Post;
use App\Models\Role;
use App\Models\User;
use App\Services\PostService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PostTabsTest extends TestCase
{
    use RefreshDatabase;

    private function author(string $villageCode, bool $badge = false): User
    {
        $user = User::factory()->create();
        $user->forceFill([
            'province_code' => substr($villageCode, 0, 2),
            'city_code' => substr($villageCode, 0, 4),
            'district_code' => substr($villageCode, 0, 7),
            'village_code' => $villageCode,
            'verified_badge_at' => $badge ? now() : null,
        ])->save();

        return $user;
    }

    private function createPost(User $author, string $body): Post
    {
        return $author->posts()->create(['body' => $body, ...$author->only(Post::REGION_COLUMNS)]);
    }

    public function test_official_tab_has_badge_holders_and_public_has_everyone_filtered_by_region(): void
    {
        $this->createPost($this->author('1101010001', badge: true), 'resmi');
        $this->createPost($this->author('1101010001'), 'desa satu');
        $this->createPost($this->author('1101010002'), 'desa dua');

        $this->getJson('/api/v1/posts?tab=official')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.body', 'resmi')
            ->assertJsonPath('data.0.user_verified_badge', true);

        $this->getJson('/api/v1/posts?tab=public')->assertOk()->assertJsonCount(3, 'data');

        $this->getJson('/api/v1/posts?tab=public&district_code=1101010&village_code=1101010002')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.body', 'desa dua');

        $this->getJson('/api/v1/posts?tab=public&village_code=1101010001')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/posts?tab=public&district_code=1101010')->assertOk()->assertJsonCount(3, 'data');
    }

    private function appoint(User $user, string $roleName, string $badgeText = 'Admin <wilayah>'): void
    {
        $user->regionAdmins()->create([
            'community_role_id' => CommunityRole::query()->where('name', $roleName)->value('id'),
            'region_level' => 'village',
            'region_code' => '1101010001',
            'region_name' => 'Latiung',
            'badge_text' => $badgeText,
        ]);
    }

    public function test_region_admin_badge_and_moderation_follow_the_region(): void
    {
        $admin = $this->author('1101010001');
        $this->appoint($admin, 'Admin');
        $inRegion = $this->createPost($this->author('1101010001'), 'warga');
        $elsewhere = $this->createPost($this->author('1101010002'), 'tetangga');
        $comment = $inRegion->comments()->create(['user_id' => $admin->id, 'body' => 'dicatat']);

        $this->actingAs($admin)->getJson("/api/v1/posts/{$inRegion->id}/comments")->assertOk()
            ->assertJsonPath('data.0.user_admin_badge', 'Admin Latiung')
            ->assertJsonPath('data.0.can_delete', true);

        $posts = collect($this->actingAs($admin)->getJson('/api/v1/posts?tab=public')->json('data'))->keyBy('id');
        $this->assertTrue($posts[$inRegion->id]['can_moderate']);
        $this->assertFalse($posts[$elsewhere->id]['can_moderate']);

        $this->actingAs($admin)->deleteJson("/api/v1/posts/{$elsewhere->id}")->assertForbidden();
        $this->actingAs($admin)->deleteJson("/api/v1/posts/{$inRegion->id}")->assertOk();
        $this->assertModelMissing($inRegion);
        $this->assertModelMissing($comment);
    }

    public function test_moderator_role_deletes_comments_and_chat_but_not_posts(): void
    {
        $moderator = $this->author('1101010002');
        $this->appoint($moderator, 'Moderator', 'Kepala Desa <wilayah>');
        $resident = $this->author('1101010001');
        $post = $this->createPost($resident, 'warga');
        $comment = $post->comments()->create(['user_id' => $resident->id, 'body' => 'spam']);
        $thread = ChatThread::create(['type' => 'region', 'region_level' => 'village', 'region_code' => '1101010001']);
        $message = $thread->messages()->create(['sender_id' => $resident->id, 'body' => 'spam']);
        $otherThread = ChatThread::create(['type' => 'region', 'region_level' => 'village', 'region_code' => '1101010002']);
        $otherMessage = $otherThread->messages()->create(['sender_id' => $resident->id, 'body' => 'boleh']);

        $this->actingAs($moderator)->getJson('/api/v1/posts?tab=public')->assertJsonPath('data.0.can_moderate', false);
        $this->actingAs($moderator)->deleteJson("/api/v1/posts/{$post->id}")->assertForbidden();

        $this->actingAs($moderator)->deleteJson("/api/v1/posts/comments/{$comment->id}")->assertOk();
        $this->assertModelMissing($comment);

        $this->actingAs($moderator)->deleteJson("/api/v1/chat/messages/{$otherMessage->id}")->assertForbidden();
        $this->actingAs($moderator)->deleteJson("/api/v1/chat/messages/{$message->id}")
            ->assertOk()
            ->assertJsonPath('data.is_deleted', true)
            ->assertJsonPath('data.body', '')
            ->assertJsonPath('data.sender_admin_badge', null);
        $this->assertNotNull($message->fresh()->deleted_at);

        // The sender may delete their own message; the badge uses the admin's wording.
        $own = $thread->messages()->create(['sender_id' => $moderator->id, 'body' => 'pengumuman']);
        $this->actingAs($moderator)->deleteJson("/api/v1/chat/messages/{$own->id}")
            ->assertOk()
            ->assertJsonPath('data.sender_admin_badge', 'Kepala Desa Latiung');
    }

    public function test_admin_manages_community_roles(): void
    {
        $this->actingAsAdmin();

        $this->getJson('/api/admin/community-roles')->assertOk()
            ->assertJsonCount(2, 'data.roles')
            ->assertJsonCount(3, 'data.abilities');

        $id = $this->postJson('/api/admin/community-roles', ['name' => 'Pengawas', 'abilities' => ['delete_chat_messages']])
            ->assertCreated()
            ->json('data.id');
        $this->putJson("/api/admin/community-roles/{$id}", ['name' => 'Pengawas', 'abilities' => ['nope']])->assertStatus(422);

        $user = $this->author('1101010001');
        $user->regionAdmins()->create([
            'community_role_id' => $id, 'region_level' => 'village', 'region_code' => '1101010001', 'region_name' => 'Latiung',
        ]);
        $this->deleteJson("/api/admin/community-roles/{$id}")->assertStatus(422);
    }

    public function test_admin_appoints_region_admin_who_joins_the_region_chat(): void
    {
        DB::table('indonesia_provinces')->insert(['code' => '11', 'name' => 'ACEH']);
        DB::table('indonesia_cities')->insert(['code' => '1101', 'province_code' => '11', 'name' => 'KAB. SIMEULUE']);
        DB::table('indonesia_districts')->insert(['code' => '1101010', 'city_code' => '1101', 'name' => 'TEUPAH SELATAN']);
        DB::table('indonesia_villages')->insert(['code' => '1101010001', 'district_code' => '1101010', 'name' => 'LATIUNG']);
        $user = User::factory()->create();
        $this->actingAsAdmin();

        $roleId = CommunityRole::query()->where('name', 'Admin')->value('id');

        $res = $this->postJson("/api/admin/customers/{$user->id}/region-admins", ['region_code' => '1101010001', 'community_role_id' => $roleId])
            ->assertOk()
            ->assertJsonPath('data.region_admins.0.label', 'Admin Latiung')
            ->assertJsonPath('data.region_admins.0.role_name', 'Admin');
        $this->assertDatabaseHas('chat_thread_participants', [
            'user_id' => $user->id,
            'thread_id' => ChatThread::query()->where('region_code', '1101010001')->value('id'),
        ]);

        $this->postJson("/api/admin/customers/{$user->id}/region-admins", ['region_code' => '9999', 'community_role_id' => $roleId])->assertStatus(422);

        $this->patchJson("/api/admin/customers/{$user->id}/region-admins/".$res->json('data.region_admins.0.id'), [
            'badge_text' => 'Kepala Desa <wilayah>',
        ])->assertOk()->assertJsonPath('data.region_admins.0.label', 'Kepala Desa Latiung');

        $this->deleteJson("/api/admin/customers/{$user->id}/region-admins/".$res->json('data.region_admins.0.id'))
            ->assertOk()
            ->assertJsonCount(0, 'data.region_admins');
    }

    public function test_feed_sorts_by_relevance_newest_or_oldest(): void
    {
        $author = $this->author('1101010001');
        $first = $this->createPost($author, 'pertama');
        $this->travel(1)->minutes();
        $second = $this->createPost($author, 'kedua');
        $this->travel(1)->minutes();
        $third = $this->createPost($author, 'ketiga');

        $ids = fn (string $query) => array_column($this->getJson("/api/v1/posts?tab=public&{$query}")->assertOk()->json('data'), 'id');

        $this->assertSame([$third->id, $second->id, $first->id], $ids('sort=newest'));
        $this->assertSame([$first->id, $second->id, $third->id], $ids('sort=oldest'));
        // Unread first (newest among them), then the rest newest first.
        $this->assertSame(
            [$second->id, $first->id, $third->id],
            $ids('sort=relevance&'.http_build_query(['unread_ids' => [$first->id, $second->id]])),
        );
        $this->assertSame([$third->id, $second->id, $first->id], $ids('sort=relevance'));
    }

    public function test_new_post_keeps_the_author_region(): void
    {
        $author = $this->author('1101010002');

        $this->actingAs($author)->postJson('/api/v1/posts', ['body' => 'halo'])->assertCreated();

        $this->assertDatabaseHas('posts', ['user_id' => $author->id, 'village_code' => '1101010002', 'district_code' => '1101010']);
    }

    public function test_recent_ids_per_tab_skip_own_posts_and_follow_region(): void
    {
        $viewer = $this->author('1101010001');
        $official = $this->createPost($this->author('1101010001', badge: true), 'resmi');
        $this->travel(1)->seconds();
        $neighbour = $this->createPost($this->author('1101010002'), 'tetangga');
        $this->createPost($viewer, 'punya sendiri');

        $this->actingAs($viewer)->getJson('/api/v1/posts/recent-ids')
            ->assertOk()
            ->assertJsonPath('data', ['official' => [$official->id], 'public' => [$neighbour->id, $official->id]]);

        $this->actingAs($viewer)->getJson('/api/v1/posts/recent-ids?village_code=1101010001')
            ->assertOk()
            ->assertJsonPath('data', ['official' => [$official->id], 'public' => [$official->id]]);
    }

    public function test_recent_ids_stop_at_the_unread_limit_newest_first(): void
    {
        $author = $this->author('1101010001');
        for ($i = 0; $i <= PostService::UNREAD_LIMIT; $i++) {
            $last = $this->createPost($author, "post {$i}");
            $this->travel(1)->seconds();
        }

        $ids = $this->getJson('/api/v1/posts/recent-ids')->assertOk()->json('data.public');

        $this->assertCount(PostService::UNREAD_LIMIT, $ids);
        $this->assertSame($last->id, $ids[0]);
    }

    public function test_admin_grants_and_removes_verified_badge(): void
    {
        $user = User::factory()->create();
        $this->actingAsAdmin();

        $this->postJson("/api/admin/customers/{$user->id}/verified-badge", ['enabled' => true])
            ->assertOk()
            ->assertJsonPath('data.has_verified_badge', true);
        $this->assertNotNull($user->fresh()->verified_badge_at);

        $this->postJson("/api/admin/customers/{$user->id}/verified-badge", ['enabled' => false])
            ->assertOk()
            ->assertJsonPath('data.has_verified_badge', false);
        $this->assertNull($user->fresh()->verified_badge_at);
    }

    private function actingAsAdmin(): void
    {
        Sanctum::actingAs(AdminUser::create([
            'name' => 'Admin',
            'email' => 'admin@example.com',
            'password' => 'secret123',
            'is_active' => true,
            'role_id' => Role::create(['name' => 'Super Admin', 'slug' => 'super_admin', 'is_system' => true])->id,
        ]), ['admin']);
    }
}
