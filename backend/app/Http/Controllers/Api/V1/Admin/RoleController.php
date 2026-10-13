<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class RoleController extends Controller
{
    /**
     * Get list of all available system permissions grouped by module.
     */
    public function availablePermissions(): JsonResponse
    {
        $permissions = [
            'dashboard' => [
                'title' => 'Dashboard & Analitik',
                'items' => [
                    ['key' => 'dashboard.view', 'label' => 'Lihat Dashboard & Ringkasan Metrik'],
                ],
            ],
            'users' => [
                'title' => 'Manajemen Pengguna',
                'items' => [
                    ['key' => 'users.view', 'label' => 'Lihat Data Pengguna'],
                    ['key' => 'users.manage', 'label' => 'Buat & Kelola Admin / Staff'],
                ],
            ],
            'roles' => [
                'title' => 'Manajemen Role',
                'items' => [
                    ['key' => 'roles.view', 'label' => 'Lihat Daftar Role'],
                    ['key' => 'roles.manage', 'label' => 'Buat, Ubah, & Hapus Hak Akses Role'],
                ],
            ],
            'catalog' => [
                'title' => 'Katalog & Produk',
                'items' => [
                    ['key' => 'catalog.view', 'label' => 'Lihat Daftar Produk & Kategori'],
                    ['key' => 'catalog.manage', 'label' => 'Tambah & Kelola Produk / Kategori'],
                ],
            ],
            'orders' => [
                'title' => 'Pesanan & Transaksi',
                'items' => [
                    ['key' => 'orders.view', 'label' => 'Lihat Daftar Pesanan'],
                    ['key' => 'orders.manage', 'label' => 'Kelola Status Pesanan & Pembatalan'],
                ],
            ],
            'delivery' => [
                'title' => 'Logistik & Driver',
                'items' => [
                    ['key' => 'delivery.view', 'label' => 'Lihat Antrean Pengiriman'],
                    ['key' => 'delivery.update', 'label' => 'Update Status Pengantaran Kurir'],
                ],
            ],
            'promotions' => [
                'title' => 'Promosi & Banner',
                'items' => [
                    ['key' => 'banners.manage', 'label' => 'Kelola Banner Slider Promo'],
                    ['key' => 'flash_sale.manage', 'label' => 'Kelola Slot Flash Sale'],
                    ['key' => 'notifications.broadcast', 'label' => 'Kirim Broadcast Notifikasi'],
                ],
            ],
            'settings' => [
                'title' => 'Pengaturan & Logistik',
                'items' => [
                    ['key' => 'settings.manage', 'label' => 'Kelola Tarif Ongkir & Payment Gateway'],
                ],
            ],
        ];

        return ApiResponse::success($permissions, 'Available permissions retrieved successfully.');
    }

    public function index(Request $request): JsonResponse
    {
        $roles = Role::query()
            ->withCount('users')
            ->orderBy('is_system', 'desc')
            ->orderBy('created_at', 'asc')
            ->get();

        return ApiResponse::success($roles, 'Roles retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'slug' => 'nullable|string|max:100|unique:roles,slug',
            'description' => 'nullable|string|max:255',
            'permissions' => 'nullable|array',
            'permissions.*' => 'string',
        ]);

        $slug = !empty($validated['slug'])
            ? Str::slug($validated['slug'], '_')
            : Str::slug($validated['name'], '_');

        // Ensure unique slug
        if (Role::where('slug', $slug)->exists()) {
            $slug = $slug . '_' . Str::random(4);
        }

        $role = Role::create([
            'name' => $validated['name'],
            'slug' => $slug,
            'description' => $validated['description'] ?? null,
            'permissions' => $validated['permissions'] ?? [],
            'is_system' => false,
        ]);

        return ApiResponse::success($role, 'Role created successfully.', [], 201);
    }

    public function show(Role $role): JsonResponse
    {
        return ApiResponse::success($role->loadCount('users'), 'Role retrieved successfully.');
    }

    public function update(Request $request, Role $role): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'description' => 'nullable|string|max:255',
            'permissions' => 'nullable|array',
            'permissions.*' => 'string',
        ]);

        $role->name = $validated['name'];
        $role->description = $validated['description'] ?? null;
        $role->permissions = $validated['permissions'] ?? [];
        $role->save();

        return ApiResponse::success($role, 'Role updated successfully.');
    }

    public function destroy(Role $role): JsonResponse
    {
        if ($role->is_system) {
            return ApiResponse::error('System role cannot be deleted.', [], 422);
        }

        if ($role->users()->count() > 0) {
            return ApiResponse::error('Role cannot be deleted because it is assigned to users.', [], 422);
        }

        $role->delete();

        return ApiResponse::success(null, 'Role deleted successfully.');
    }
}
