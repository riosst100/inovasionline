<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Support\Permissions\AdminMenu;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class RoleController extends Controller
{
    /**
     * Grantable permissions: a view/manage pair per admin menu (see AdminMenu) plus extras.
     */
    public function availablePermissions(): JsonResponse
    {
        return ApiResponse::success(AdminMenu::catalog(), 'Available permissions retrieved successfully.');
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
            'permissions.*' => ['string', Rule::in(['*', ...AdminMenu::permissionKeys()])],
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
            'permissions.*' => ['string', Rule::in(['*', ...AdminMenu::permissionKeys()])],
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
