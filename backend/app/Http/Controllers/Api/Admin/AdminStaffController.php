<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdminUserResource;
use App\Models\AdminUser;
use App\Models\Role;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AdminStaffController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = AdminUser::query()
            ->with('role')
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('username', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->when($request->string('role_id')->toString(), fn ($query, $roleId) => $query->where('role_id', $roleId))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, AdminUserResource::class, 'Daftar staff admin berhasil dimuat.');
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'username' => ['required', 'string', AdminUser::USERNAME_RULE, Rule::unique('admin_users', 'username')],
            'email' => 'required|email|max:150|unique:admin_users,email',
            'phone' => 'nullable|string|max:30|unique:admin_users,phone',
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
        ]);

        $adminUser = AdminUser::create([
            'name' => $validated['name'],
            'username' => $validated['username'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => Hash::make($validated['password']),
            'role_id' => $validated['role_id'],
            'is_active' => true,
        ]);

        return ApiResponse::success(
            new AdminUserResource($adminUser->load('role')),
            'User admin/staff berhasil dibuat.',
            [],
            201
        );
    }

    public function show(AdminUser $adminUser): JsonResponse
    {
        return ApiResponse::success(new AdminUserResource($adminUser->load('role')), 'Detail user admin berhasil dimuat.');
    }

    public function update(Request $request, AdminUser $adminUser): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'username' => ['required', 'string', AdminUser::USERNAME_RULE, Rule::unique('admin_users', 'username')->ignore($adminUser->id)],
            'email' => ['required', 'email', 'max:150', Rule::unique('admin_users', 'email')->ignore($adminUser->id)],
            'phone' => ['nullable', 'string', 'max:30', Rule::unique('admin_users', 'phone')->ignore($adminUser->id)],
            'password' => 'nullable|string|min:6',
            'role_id' => 'nullable|exists:roles,id',
            'is_active' => 'nullable|boolean',
        ]);

        $data = [
            'name' => $validated['name'],
            'username' => $validated['username'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
        ];

        if (!empty($validated['password'])) {
            $data['password'] = Hash::make($validated['password']);
        }

        if (isset($validated['role_id'])) {
            $data['role_id'] = $validated['role_id'];
        }

        if (isset($validated['is_active'])) {
            $data['is_active'] = $validated['is_active'];
        }

        $adminUser->update($data);

        return ApiResponse::success(new AdminUserResource($adminUser->fresh()->load('role')), 'User admin berhasil diperbarui.');
    }

    public function destroy(Request $request, AdminUser $adminUser): JsonResponse
    {
        $currentAdmin = $request->user();

        if ($currentAdmin && $currentAdmin->id === $adminUser->id) {
            return ApiResponse::error('Anda tidak dapat menghapus akun Anda sendiri.', [], 422);
        }

        $adminUser->delete();

        return ApiResponse::success(null, 'User admin berhasil dihapus.');
    }
}
