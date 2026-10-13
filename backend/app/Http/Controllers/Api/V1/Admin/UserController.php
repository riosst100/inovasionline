<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\Role;
use App\Models\User;
use App\Support\Enums\UserRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = User::query()
            ->with('assignedRole')
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->when($request->boolean('only_staff'), function ($query) {
                $query->where(function ($q) {
                    $q->whereNotNull('role_id')
                        ->orWhere('role', UserRole::PLATFORM_ADMIN);
                });
            })
            ->when($request->string('role_id')->toString(), fn ($query, $roleId) => $query->where('role_id', $roleId))
            ->when($request->string('role')->toString(), fn ($query, $role) => $query->where('role', $role))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, UserResource::class, 'Users retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'email' => 'required|email|max:150|unique:users,email',
            'phone' => 'nullable|string|max:30|unique:users,phone',
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
        ]);

        $role = Role::findOrFail($validated['role_id']);
        
        // If assigned super_admin or admin system role, mark role column as PLATFORM_ADMIN
        $userRole = in_array($role->slug, ['super_admin', 'admin']) 
            ? UserRole::PLATFORM_ADMIN 
            : UserRole::CUSTOMER;

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => Hash::make($validated['password']),
            'role' => $userRole,
            'role_id' => $role->id,
            'email_verified_at' => now(),
        ]);

        return ApiResponse::success(new UserResource($user->load('assignedRole')), 'Admin/staff user created successfully.', [], 201);
    }

    public function show(User $user): JsonResponse
    {
        return ApiResponse::success(new UserResource($user->load('assignedRole')), 'User retrieved successfully.');
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'email' => ['required', 'email', 'max:150', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['nullable', 'string', 'max:30', Rule::unique('users', 'phone')->ignore($user->id)],
            'password' => 'nullable|string|min:6',
            'role_id' => 'nullable|exists:roles,id',
        ]);

        $data = [
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
        ];

        if (!empty($validated['password'])) {
            $data['password'] = Hash::make($validated['password']);
        }

        if (isset($validated['role_id'])) {
            $role = Role::find($validated['role_id']);
            $data['role_id'] = $role?->id;
            if ($role && in_array($role->slug, ['super_admin', 'admin'])) {
                $data['role'] = UserRole::PLATFORM_ADMIN;
            }
        }

        $user->update($data);

        return ApiResponse::success(new UserResource($user->fresh()->load('assignedRole')), 'User updated successfully.');
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $currentUser = $request->user();

        if ($currentUser && $currentUser->id === $user->id) {
            return ApiResponse::error('Anda tidak dapat menghapus akun Anda sendiri.', [], 422);
        }

        $user->delete();

        return ApiResponse::success(null, 'User deleted successfully.');
    }
}
