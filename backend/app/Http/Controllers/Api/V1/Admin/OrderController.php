<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\MidtransService;
use App\Services\NotificationService;
use App\Services\OrderCancellationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use RuntimeException;

class OrderController extends Controller
{
    private const STATUS_MESSAGES = [
        'processing' => 'Pesanan Anda sedang disiapkan.',
        'ready' => 'Pesanan Anda sudah disiapkan.',
        'on_delivery' => 'Pesanan Anda sedang diantar ke alamat kamu.',
        'completed' => 'Pesanan Anda telah selesai. Terima kasih!',
        'cancelled' => 'Pesanan Anda dibatalkan oleh penjual.',
    ];

    public function __construct(
        private readonly OrderCancellationService $cancellationService,
        private readonly MidtransService $midtrans,
        private readonly NotificationService $notifications,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $search = trim($request->string('search')->toString());

        $orders = Order::with(['user', 'paymentMethod'])
            ->withCount('items')
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->when($request->filled('payment_status'), fn ($q) => $q->where('payment_status', $request->string('payment_status')))
            ->when($search !== '', fn ($q) => $this->applySearch($q, $search))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($orders, OrderResource::class, 'Orders retrieved successfully.');
    }

    /**
     * Order count per status (plus `all`) for the admin status tabs, using the same search as index().
     */
    public function counts(Request $request): JsonResponse
    {
        $search = trim($request->string('search')->toString());

        $rows = Order::query()
            ->when($search !== '', fn ($q) => $this->applySearch($q, $search))
            ->toBase()
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $counts = ['all' => (int) $rows->sum()];
        foreach (OrderStatus::cases() as $status) {
            $counts[$status->value] = (int) ($rows[$status->value] ?? 0);
        }

        return ApiResponse::success($counts, 'Order counts retrieved successfully.');
    }

    private function applySearch(Builder $query, string $search): Builder
    {
        return $query->where(fn ($q) => $q
            ->where('order_number', 'ilike', "%{$search}%")
            ->orWhereHas('user', fn ($u) => $u->where('name', 'ilike', "%{$search}%")));
    }

    public function show(Order $order): JsonResponse
    {
        $order->load(['user', 'items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Order retrieved successfully.');
    }

    public function updateStatus(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::enum(OrderStatus::class)],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $next = OrderStatus::from($data['status']);

        if (! $order->canTransitionTo($next)) {
            return ApiResponse::error('Status pesanan tidak dapat diubah ke tahap tersebut.', [], 422);
        }

        $by = 'admin:'.$request->user()->id;

        if ($next === OrderStatus::CANCELLED) {
            $wasUnpaid = $order->payment_status === PaymentStatus::UNPAID;

            try {
                // Paid orders are credited back to the buyer's balance inside cancel().
                $order = $this->cancellationService->cancel($order, $by);
            } catch (RuntimeException $e) {
                return ApiResponse::error($e->getMessage(), [], 422);
            }

            // Kill the still-open VA/QR so the cancelled order cannot be paid later.
            if ($wasUnpaid) {
                $this->midtrans->cancelTransaction($order);
            }
        } else {
            $order->update([
                'status' => $next,
                'status_history' => [
                    ...($order->status_history ?? []),
                    ['status' => $next->value, 'at' => now()->toIso8601String(), 'by' => $by],
                ],
                ...match ($next) {
                    OrderStatus::COMPLETED => ['completed_at' => now()],
                    default => [],
                },
            ]);
        }

        if (array_key_exists('admin_notes', $data)) {
            $order->update(['admin_notes' => $data['admin_notes']]);
        }

        $this->notifyBuyer($order, $next);

        $order->load(['user', 'items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Status pesanan berhasil diperbarui.');
    }

    private function notifyBuyer(Order $order, OrderStatus $status): void
    {
        $user = $order->user;
        $body = self::STATUS_MESSAGES[$status->value] ?? null;

        if ($user === null || $body === null) {
            return;
        }

        try {
            $this->notifications->sendToUser($user, "Pesanan {$order->order_number}", $body, [
                'type' => 'order',
                'order_id' => $order->id,
            ]);
        } catch (\Throwable $e) {
            Log::warning('Order status push failed: '.$e->getMessage());
        }
    }
}
