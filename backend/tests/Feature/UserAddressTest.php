<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class UserAddressTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        DB::table('indonesia_provinces')->insert(['code' => '11', 'name' => 'ACEH']);
        DB::table('indonesia_cities')->insert(['code' => '1101', 'province_code' => '11', 'name' => 'KAB. SIMEULUE']);
        DB::table('indonesia_districts')->insert(['code' => '1101010', 'city_code' => '1101', 'name' => 'TEUPAH SELATAN']);
        DB::table('indonesia_villages')->insert([
            ['code' => '1101010001', 'district_code' => '1101010', 'name' => 'LATIUNG'],
            ['code' => '1101010002', 'district_code' => '1101010', 'name' => 'LABUHAN BAJAU'],
        ]);
    }

    private function payload(array $overrides = []): array
    {
        return [
            'label' => 'Rumah',
            'recipient_name' => 'Budi',
            'recipient_phone' => '08123456789',
            'province_code' => '11',
            'city_code' => '1101',
            'district_code' => '1101010',
            'village_code' => '1101010001',
            'address_detail' => 'Jl. Mawar 5, RT 02',
            ...$overrides,
        ];
    }

    public function test_user_saves_several_addresses_and_lists_newest_first(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/auth/user/addresses', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.recipient_name', 'Budi')
            ->assertJsonPath('data.village.code', '1101010001')
            ->assertJsonPath('data.village.name', 'LATIUNG')
            ->assertJsonPath('data.province.name', 'ACEH');

        $this->travel(1)->minutes();

        $this->actingAs($user)->postJson('/api/v1/auth/user/addresses', $this->payload([
            'label' => 'Kantor',
            'village_code' => '1101010002',
        ]))->assertCreated();

        $this->actingAs($user)->getJson('/api/v1/auth/user/addresses')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.label', 'Kantor')
            ->assertJsonPath('data.1.label', 'Rumah');
    }

    public function test_user_updates_and_deletes_an_address(): void
    {
        $user = User::factory()->create();
        $address = $user->addresses()->create($this->payload());

        $this->actingAs($user)->putJson("/api/v1/auth/user/addresses/{$address->id}", $this->payload([
            'address_detail' => 'Jl. Melati 9',
        ]))->assertOk()->assertJsonPath('data.address_detail', 'Jl. Melati 9');

        $this->actingAs($user)->deleteJson("/api/v1/auth/user/addresses/{$address->id}")->assertOk();

        $this->assertDatabaseMissing('user_addresses', ['id' => $address->id]);
    }

    public function test_other_users_addresses_are_not_reachable(): void
    {
        $owner = User::factory()->create();
        $address = $owner->addresses()->create($this->payload());
        $other = User::factory()->create();

        $this->actingAs($other)->getJson('/api/v1/auth/user/addresses')->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($other)->putJson("/api/v1/auth/user/addresses/{$address->id}", $this->payload())->assertNotFound();
        $this->actingAs($other)->deleteJson("/api/v1/auth/user/addresses/{$address->id}")->assertNotFound();

        $this->assertDatabaseHas('user_addresses', ['id' => $address->id]);
    }

    public function test_incomplete_address_is_rejected(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/auth/user/addresses', $this->payload([
            'label' => 'Rumah Nenek',
            'address_detail' => '',
            'village_code' => '9999999999',
        ]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['label', 'address_detail', 'village_code']);
    }
}
