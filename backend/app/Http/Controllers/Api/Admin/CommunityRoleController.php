<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\CommunityRole;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Community roles (Admin, Moderator, ...) and what each may do in the regions its members are appointed to. */
class CommunityRoleController extends Controller
{
    public function index(): JsonResponse
    {
        return ApiResponse::success([
            'roles' => CommunityRole::query()->withCount('appointments')->orderBy('name')->get()->map(fn ($r) => $this->payload($r)),
            'abilities' => collect(CommunityRole::ABILITIES)->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values(),
        ], 'Daftar peran komunitas berhasil dimuat.');
    }

    public function store(Request $request): JsonResponse
    {
        $role = CommunityRole::create($this->validated($request));

        return ApiResponse::success($this->payload($role->loadCount('appointments')), 'Peran berhasil ditambahkan.', [], 201);
    }

    public function update(Request $request, CommunityRole $role): JsonResponse
    {
        $role->update($this->validated($request, $role));

        return ApiResponse::success($this->payload($role->loadCount('appointments')), 'Peran berhasil disimpan.');
    }

    public function destroy(CommunityRole $role): JsonResponse
    {
        if ($role->appointments()->exists()) {
            return ApiResponse::error('Peran masih dipakai. Ganti atau cabut dulu penunjukan yang memakainya.', [], 422);
        }
        $role->delete();

        return ApiResponse::success(null, 'Peran berhasil dihapus.');
    }

    private function validated(Request $request, ?CommunityRole $role = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:50', Rule::unique('community_roles', 'name')->ignore($role?->id)],
            'abilities' => ['present', 'array'],
            'abilities.*' => [Rule::in(array_keys(CommunityRole::ABILITIES))],
        ], [
            'name.required' => 'Nama peran wajib diisi.',
            'name.unique' => 'Nama peran sudah dipakai.',
        ]);
    }

    private function payload(CommunityRole $role): array
    {
        return [
            'id' => $role->id,
            'name' => $role->name,
            'abilities' => $role->abilities ?? [],
            'appointments_count' => (int) ($role->appointments_count ?? 0),
        ];
    }
}
