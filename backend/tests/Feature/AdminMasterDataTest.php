<?php

namespace Tests\Feature;

use App\Models\AdminUser;
use App\Models\Brand;
use App\Models\Product;
use App\Models\Role;
use App\Models\Supplier;
use App\Support\DataTransfer\DataTransferRegistry;
use App\Support\DataTransfer\ImportResult;
use App\Support\DataTransfer\RowSkippedException;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
