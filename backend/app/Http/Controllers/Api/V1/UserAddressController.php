<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\UserAddressRequest;
use App\Http\Resources\UserAddressResource;
use App\Models\UserAddress;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserAddressController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $addresses = $request->user()->addresses()->recentFirst()->get();

        return ApiResponse::success(UserAddressResource::collection($addresses));
    }

    public function store(UserAddressRequest $request): JsonResponse
    {
        $address = $request->user()->addresses()->create([
            ...$request->validated(),
            'last_used_at' => now(),
        ]);

        return ApiResponse::success(new UserAddressResource($address), 'Address saved successfully.', [], 201);
    }

    public function update(UserAddressRequest $request, string $address): JsonResponse
    {
        $model = $this->find($request, $address);
        $model->update($request->validated());

        return ApiResponse::success(new UserAddressResource($model), 'Address updated successfully.');
    }

    public function destroy(Request $request, string $address): JsonResponse
    {
        $this->find($request, $address)->delete();

        return ApiResponse::success(null, 'Address deleted successfully.');
    }

    /** Only the signed-in user's own addresses; anything else is a 404. */
    private function find(Request $request, string $id): UserAddress
    {
        return $request->user()->addresses()->findOrFail($id);
    }
}
