<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = User::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, UserResource::class, 'Daftar customer berhasil dimuat.');
    }

    public function show(User $user): JsonResponse
    {
        return ApiResponse::success(new UserResource($user), 'Detail customer berhasil dimuat.');
    }
}
