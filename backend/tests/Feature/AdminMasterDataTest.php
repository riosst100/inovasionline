<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Brand;
use App\Models\Product;
use App\Models\ProductAttribute;
use App\Models\Role;
use App\Models\Supplier;
use App\Support\DataTransfer\DataTransferRegistry;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminMasterDataTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_manage_suppliers(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $id = $this->postJson('/api/admin/suppliers', [
            'name' => 'PT Sumber Makmur',
            'phone' => '08123456789',
            'email' => 'sales@sumber.test',
        ])->assertCreated()->json('data.id');

        $this->putJson("/api/admin/suppliers/{$id}", ['name' => 'PT Sumber Jaya', 'is_active' => false])
            ->assertSuccessful()
            ->assertJsonPath('data.name', 'PT Sumber Jaya')
            ->assertJsonPath('data.is_active', false);

        $this->getJson('/api/admin/suppliers')->assertSuccessful()->assertJsonCount(1, 'data');

        $this->deleteJson("/api/admin/suppliers/{$id}")->assertSuccessful();
        $this->assertDatabaseMissing('suppliers', ['id' => $id]);
    }

    public function test_brand_names_are_unique(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $this->postJson('/api/admin/brands', ['name' => 'Indomie'])->assertCreated();
        $this->postJson('/api/admin/brands', ['name' => 'Indomie'])->assertUnprocessable()->assertJsonValidationErrors('name');
    }

    public function test_product_supplier_and_brand_are_optional_and_nulled_on_delete(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);
        $supplier = Supplier::create(['name' => 'CV Grosir']);
        $brand = Brand::create(['name' => 'Bimoli']);

        $this->postJson('/api/admin/products', [
            'name' => 'Tanpa Brand',
            'regular_price' => 5000,
            'status' => 'active',
        ])->assertSuccessful()->assertJsonPath('data.supplier_id', null)->assertJsonPath('data.brand_id', null);

        $productId = $this->postJson('/api/admin/products', [
            'name' => 'Minyak 2L',
            'regular_price' => 30000,
            'supplier_id' => $supplier->id,
            'brand_id' => $brand->id,
            'status' => 'active',
        ])->assertSuccessful()
            ->assertJsonPath('data.supplier_name', 'CV Grosir')
            ->assertJsonPath('data.brand_name', 'Bimoli')
            ->json('data.id');

        $this->deleteJson("/api/admin/suppliers/{$supplier->id}")->assertSuccessful();
        $this->deleteJson("/api/admin/brands/{$brand->id}")->assertSuccessful();

        $product = Product::find($productId);
        $this->assertNull($product->supplier_id);
        $this->assertNull($product->brand_id);
    }

    public function test_supplier_and_brand_import_create_then_update(): void
    {
        $suppliers = DataTransferRegistry::handler('suppliers');
        $brands = DataTransferRegistry::handler('brands');

        $this->assertSame(ImportResult::CREATED, $suppliers->importRow(['name' => 'CV Grosir', 'phone' => '0811']));
        $this->assertSame(ImportResult::UPDATED, $suppliers->importRow(['name' => 'cv grosir', 'is_active' => '0']));
        $supplier = Supplier::sole();
        $this->assertSame('0811', $supplier->phone);
        $this->assertFalse($supplier->is_active);
        $this->assertSame(ImportResult::UPDATED, $suppliers->importRow(['id' => $supplier->id, 'name' => 'CV Grosir Baru']));
        $this->assertSame('CV Grosir Baru', $supplier->fresh()->name);

        $this->assertSame(ImportResult::CREATED, $brands->importRow(['name' => 'Bimoli', 'description' => 'Minyak']));
        $this->assertSame(ImportResult::UPDATED, $brands->importRow(['name' => 'BIMOLI', 'description' => 'Minyak goreng']));
        $this->assertSame('Minyak goreng', Brand::sole()->description);

        $this->expectException(RowSkippedException::class);
        $suppliers->importRow(['name' => 'X', 'email' => 'bukan-email']);
    }

    public function test_attribute_import_create_then_update_and_protects_system_attributes(): void
    {
        $attributes = DataTransferRegistry::handler('attributes');

        $this->assertSame(ImportResult::CREATED, $attributes->importRow([
            'code' => 'warna', 'name' => 'Warna', 'type' => 'select', 'options' => 'Merah| Biru |Merah',
        ]));
        $this->assertSame(ImportResult::UPDATED, $attributes->importRow([
            'code' => 'warna', 'name' => 'Warna Produk', 'type' => 'select', 'options' => 'Hijau', 'is_active' => '0',
        ]));
        $warna = ProductAttribute::where('code', 'warna')->sole();
        $this->assertSame(['Hijau'], $warna->options);
        $this->assertFalse($warna->is_active);
        $this->assertFalse($warna->is_system);

        $system = ProductAttribute::updateOrCreate(['code' => 'sku_test'], [
            'name' => 'SKU', 'type' => 'text', 'is_system' => true, 'is_required' => true, 'is_active' => true,
        ]);
        $this->assertSame(ImportResult::UPDATED, $attributes->importRow([
            'code' => 'sku_test', 'name' => 'Kode SKU', 'type' => 'number', 'is_active' => '0',
        ]));
        $system->refresh();
        $this->assertSame('Kode SKU', $system->name);
        $this->assertSame('text', $system->type);
        $this->assertTrue($system->is_active);

        $this->expectException(RowSkippedException::class);
        $attributes->importRow(['code' => 'ukuran', 'name' => 'Ukuran', 'type' => 'select']);
    }

    public function test_driver_import_creates_with_password_and_never_touches_other_admins(): void
    {
        $drivers = DataTransferRegistry::handler('drivers');
        $staff = $this->admin();

        try {
            $drivers->importRow(['name' => 'Budi', 'email' => 'budi@example.com']);
            $this->fail('A new courier without password must be skipped.');
        } catch (RowSkippedException) {
        }

        $this->assertSame(ImportResult::CREATED, $drivers->importRow([
            'name' => 'Budi', 'email' => 'Budi@Example.com', 'phone' => '0811', 'password' => 'rahasia1',
        ]));
        $driver = AdminUser::where('email', 'budi@example.com')->sole();
        $this->assertSame('driver', $driver->role->slug);
        $this->assertSame('Motor', $driver->vehicle_type);
        $this->assertTrue(Hash::check('rahasia1', $driver->password));

        $this->assertSame(ImportResult::UPDATED, $drivers->importRow([
            'name' => 'Budi S', 'email' => 'budi@example.com', 'vehicle_plate_number' => 'B 1 AB', 'password' => '',
        ]));
        $driver->refresh();
        $this->assertSame('Budi S', $driver->name);
        $this->assertSame('B 1 AB', $driver->vehicle_plate_number);
        $this->assertTrue(Hash::check('rahasia1', $driver->password));

        $exported = $drivers->exportQuery([])->get();
        $this->assertSame([$driver->id], $exported->pluck('id')->all());
        $this->assertNull($drivers->exportRow($exported->first())['password']);

        $this->expectException(RowSkippedException::class);
        $drivers->importRow(['name' => 'X', 'email' => $staff->email, 'password' => 'rahasia1']);
    }

    public function test_driver_plate_number_can_be_changed_and_cleared(): void
    {
        Sanctum::actingAs($this->admin(), ['admin']);

        $id = $this->postJson('/api/admin/drivers', [
            'name' => 'Budi', 'email' => 'budi@example.com', 'password' => 'rahasia1', 'vehicle_plate_number' => 'B 1 AB',
        ])->assertCreated()->json('data.id');

        $this->putJson("/api/admin/drivers/{$id}", ['name' => 'Budi', 'email' => 'budi@example.com', 'vehicle_plate_number' => 'B 2 CD'])
            ->assertSuccessful()
            ->assertJsonPath('data.vehicle_plate_number', 'B 2 CD');

        $this->putJson("/api/admin/drivers/{$id}", ['name' => 'Budi', 'email' => 'budi@example.com', 'vehicle_plate_number' => ''])
            ->assertSuccessful()
            ->assertJsonPath('data.vehicle_plate_number', null);
    }

    public function test_product_import_resolves_supplier_and_brand_by_name(): void
    {
        $supplier = Supplier::create(['name' => 'CV Grosir']);
        $brand = Brand::create(['name' => 'Bimoli']);
        $handler = DataTransferRegistry::handler('products');

        $handler->importRow(['sku' => 'MNY-1', 'name' => 'Minyak', 'regular_price' => '20000', 'supplier' => 'cv grosir', 'brand' => 'Bimoli']);
        $product = Product::where('sku', 'MNY-1')->sole();
        $this->assertSame($supplier->id, $product->supplier_id);
        $this->assertSame($brand->id, $product->brand_id);

        $row = $handler->exportRow($handler->exportQuery([])->first());
        $this->assertSame('CV Grosir', $row['supplier']);
        $this->assertSame('Bimoli', $row['brand']);

        $this->expectException(RowSkippedException::class);
        $handler->importRow(['sku' => 'MNY-1', 'brand' => 'Tidak Ada']);
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
