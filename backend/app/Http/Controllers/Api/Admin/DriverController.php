<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdminUserResource;
use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Role;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class DriverController extends Controller
{
    /**
     * Get list of drivers with their total delivered orders count.
     */
    public function index(Request $request): JsonResponse
    {
        $driverRole = Role::where('slug', 'driver')->first();

        $paginator = AdminUser::query()
            ->with('role')
            ->withCount('deliveredOrders')
            ->when($driverRole, fn ($q) => $q->where('role_id', $driverRole->id))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('vehicle_plate_number', 'like', "%{$search}%");
                });
            })
            ->when($request->has('is_active'), function ($query) use ($request) {
                $query->where('is_active', $request->boolean('is_active'));
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, AdminUserResource::class, 'Daftar driver berhasil dimuat.');
    }

    /**
     * Add a new driver.
     */
    public function store(Request $request): JsonResponse
    {
        $driverRole = Role::firstOrCreate(
            ['slug' => 'driver'],
            [
                'name' => 'Driver',
                'description' => 'Petugas kurir pengantaran barang dan update status ekspedisi pengiriman.',
                'permissions' => ['orders.view', 'delivery.view', 'delivery.update'],
                'is_system' => false,
            ]
        );

        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'email' => 'required|email|max:150|unique:admin_users,email',
            'phone' => 'nullable|string|max:30|unique:admin_users,phone',
            'password' => 'required|string|min:6',
            'vehicle_type' => 'nullable|string|max:50',
            'vehicle_plate_number' => 'nullable|string|max:30',
            'is_active' => 'nullable|boolean',
        ]);

        $driver = AdminUser::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => Hash::make($validated['password']),
            'role_id' => $driverRole->id,
            'vehicle_type' => $validated['vehicle_type'] ?? 'Motor',
            'vehicle_plate_number' => $validated['vehicle_plate_number'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return ApiResponse::success(
            new AdminUserResource($driver->load('role')),
            'Driver baru berhasil ditambahkan.',
            [],
            201
        );
    }

    public function show(AdminUser $driver): JsonResponse
    {
        return ApiResponse::success(
            new AdminUserResource($driver->load('role')->loadCount('deliveredOrders')),
            'Detail driver berhasil dimuat.'
        );
    }

    /**
     * Update driver details.
     */
    public function update(Request $request, AdminUser $driver): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'email' => ['required', 'email', 'max:150', Rule::unique('admin_users', 'email')->ignore($driver->id)],
            'phone' => ['nullable', 'string', 'max:30', Rule::unique('admin_users', 'phone')->ignore($driver->id)],
            'password' => 'nullable|string|min:6',
            'vehicle_type' => 'nullable|string|max:50',
            'vehicle_plate_number' => 'nullable|string|max:30',
            'is_active' => 'nullable|boolean',
        ]);

        $data = [
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'vehicle_type' => $validated['vehicle_type'] ?? $driver->vehicle_type,
            'vehicle_plate_number' => $validated['vehicle_plate_number'] ?? $driver->vehicle_plate_number,
        ];

        if (!empty($validated['password'])) {
            $data['password'] = Hash::make($validated['password']);
        }

        if (isset($validated['is_active'])) {
            $data['is_active'] = $validated['is_active'];
        }

        $driver->update($data);

        return ApiResponse::success(
            new AdminUserResource($driver->fresh()->load('role')->loadCount('deliveredOrders')),
            'Data driver berhasil diperbarui.'
        );
    }

    /**
     * Set driver status enable / disable.
     */
    public function setStatus(Request $request, AdminUser $driver): JsonResponse
    {
        $validated = $request->validate([
            'is_active' => 'required|boolean',
        ]);

        $driver->is_active = $validated['is_active'];
        $driver->save();

        $statusText = $driver->is_active ? 'diaktifkan (Enable)' : 'dinonaktifkan (Disable)';

        return ApiResponse::success(
            new AdminUserResource($driver->fresh()->load('role')->loadCount('deliveredOrders')),
            "Status driver berhasil {$statusText}."
        );
    }

    /**
     * Delete driver.
     */
    public function destroy(AdminUser $driver): JsonResponse
    {
        $driver->delete();

        return ApiResponse::success(null, 'Driver berhasil dihapus.');
    }

    /**
     * Get list of orders assigned / delivered by this driver.
     * Clicked from the driver list total orders count.
     */
    public function orders(Request $request, AdminUser $driver): JsonResponse
    {
        $paginator = Order::query()
            ->where('driver_id', $driver->id)
            ->with(['user', 'store', 'items.product'])
            ->latest()
            ->paginate($request->integer('per_page', 10));

        $data = $paginator->through(function (Order $order) {
            $address = is_array($order->delivery_address) ? $order->delivery_address : [];
            $fullAddress = $address['address_line'] ?? ($address['full_address'] ?? 'Alamat pengiriman');

            return [
                'id' => $order->id,
                'order_number' => $order->order_number,
                'customer_name' => $order->user?->name ?? 'Pelanggan',
                'customer_phone' => $order->user?->phone ?? '-',
                'delivery_address' => $fullAddress,
                'status' => $order->status->value,
                'payment_status' => $order->payment_status->value,
                'grand_total' => (float) $order->grand_total,
                'total_items' => $order->items->sum('quantity'),
                'created_at' => $order->created_at->toISOString(),
                'completed_at' => $order->completed_at?->toISOString(),
            ];
        });

        return ApiResponse::success(
            $data->items(),
            'Daftar pesanan driver berhasil dimuat.',
            [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }
}
