<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\DeliverySchedule;
use App\Models\Order;
use App\Models\OrderSetting;
use App\Services\MidtransService;
use App\Services\NotificationService;
use App\Services\OrderCancellationService;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Responses\ApiResponse;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
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

    /** Not yet handed to the courier. */
    private const AWAITING_DISPATCH = [OrderStatus::PENDING, OrderStatus::PROCESSING, OrderStatus::READY];

    private const INSTANT_LIMIT = 20;

    private const SCHEDULED_LIMIT = 200;

    public function __construct(
        private readonly OrderCancellationService $cancellationService,
        private readonly MidtransService $midtrans,
        private readonly NotificationService $notifications,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $orders = $this->filtered($request, Order::with(['user', 'paymentMethod', 'shippingMethod']))
            ->withCount('items')
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->string('status')))
            ->when($request->filled('payment_status'), fn ($q) => $q->where('payment_status', $request->string('payment_status')))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($orders, OrderResource::class, 'Orders retrieved successfully.');
    }

    /**
     * Order count per status (plus `all`) for the admin status tabs, using the same filters as index().
     */
    public function counts(Request $request): JsonResponse
    {
        $rows = $this->filtered($request, Order::query())
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

    /**
     * Instant orders (no delivery schedule) not yet handed to the courier, longest waiting first,
     * each with the deadline to ship it (order time + instant_dispatch_minutes). The admin panel
     * polls this for its global alert, timers and sound.
     */
    public function instant(): JsonResponse
    {
        $minutes = OrderSetting::current()->toPayload()['instant_dispatch_minutes'];
        $query = self::instantQueue();

        return ApiResponse::success([
            'dispatch_minutes' => $minutes,
            'count' => (clone $query)->count(),
            // Nobody started packing yet; the panel keeps ringing while this is above zero.
            'unpacked' => (clone $query)->where('status', OrderStatus::PENDING)->count(),
            // Every unfinished order (scheduled and on delivery too), for the Pesanan menu badge.
            'open' => Order::query()->whereIn('status', SalesReportController::OPEN_STATUSES)->count(),
            'orders' => $query
                ->with('user:id,name')
                ->oldest()
                ->limit(self::INSTANT_LIMIT)
                ->get()
                ->map(fn (Order $o) => [
                    'id' => $o->id,
                    'order_number' => $o->order_number,
                    'customer' => $o->user?->name,
                    'grand_total' => (float) $o->grand_total,
                    'status' => $o->status->value,
                    'created_at' => $o->created_at,
                    'deadline_at' => $o->created_at->copy()->addMinutes($minutes),
                ])
                ->all(),
        ], 'Instant orders retrieved successfully.');
    }

    /**
     * Scheduled orders for one delivery date (WIB, default today): the time slots that run that day,
     * each with its order count and quota, and the (non-cancelled) orders themselves. Slots that don't
     * run that weekday still show up when orders were booked on them.
     */
    public function scheduled(Request $request): JsonResponse
    {
        $date = $request->validate(['date' => ['nullable', 'date_format:Y-m-d']])['date']
            ?? now(WalletTopupController::TIMEZONE)->toDateString();
        $weekday = Carbon::createFromFormat('Y-m-d', $date)->dayOfWeekIso;

        $orders = Order::query()
            ->with('user:id,name')
            ->whereDate('delivery_date', $date)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->oldest()
            ->limit(self::SCHEDULED_LIMIT)
            ->get();
        $counts = Order::query()
            ->whereDate('delivery_date', $date)
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->toBase()
            ->selectRaw('delivery_schedule_id, count(*) as total')
            ->groupBy('delivery_schedule_id')
            ->pluck('total', 'delivery_schedule_id');

        $slots = DeliverySchedule::query()
            ->with('shippingMethod:id,name')
            ->where(fn ($q) => $q->where('is_active', true)->orWhereIn('id', $counts->keys()->filter()))
            ->orderBy('start_time')
            ->orderBy('sort_order')
            ->get()
            ->filter(fn (DeliverySchedule $s) => $counts->has($s->id) || $s->runsOn($weekday))
            ->map(fn (DeliverySchedule $s) => [
                'id' => $s->id,
                'label' => $s->label,
                'time_range' => $s->timeRange(),
                'shipping_method' => $s->shippingMethod?->name,
                'quota' => $s->quota,
                'count' => (int) ($counts[$s->id] ?? 0),
            ])
            ->values();

        return ApiResponse::success([
            'date' => $date,
            'count' => (int) $counts->sum(),
            'slots' => $slots,
            'orders' => $orders->map(fn (Order $o) => [
                'id' => $o->id,
                'order_number' => $o->order_number,
                'customer' => $o->user?->name,
                'grand_total' => (float) $o->grand_total,
                'status' => $o->status->value,
                'delivery_schedule_id' => $o->delivery_schedule_id,
                'created_at' => $o->created_at,
            ]),
        ], 'Scheduled orders retrieved successfully.');
    }

    /** Instant orders still waiting to be shipped. */
    public static function instantQueue(): Builder
    {
        return Order::query()->whereIn('status', self::AWAITING_DISPATCH)->whereNull('delivery_date');
    }

    /**
     * Filters of the admin order table (everything but the status tab): search on order number /
     * buyer, order date range (WIB days), shipping method and grand total range.
     */
    private function filtered(Request $request, Builder $query): Builder
    {
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'date_from' => ['nullable', 'date_format:Y-m-d'],
            'date_to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:date_from'],
            'shipping_method_id' => ['nullable', 'string', 'max:26'],
            'total_min' => ['nullable', 'numeric', 'min:0'],
            'total_max' => ['nullable', 'numeric', 'min:0'],
        ]);
        $search = trim($data['search'] ?? '');

        return $query
            ->when($search !== '', fn ($q) => $this->applySearch($q, $search))
            ->when($data['date_from'] ?? null, fn ($q, $d) => $q->where('created_at', '>=', WalletTopupController::startOfDay($d)))
            ->when($data['date_to'] ?? null, fn ($q, $d) => $q->where('created_at', '<', WalletTopupController::startOfDay($d)->addDay()))
            ->when($data['shipping_method_id'] ?? null, fn ($q, $id) => $q->where('shipping_method_id', $id))
            ->when(isset($data['total_min']), fn ($q) => $q->where('grand_total', '>=', $data['total_min']))
            ->when(isset($data['total_max']), fn ($q) => $q->where('grand_total', '<=', $data['total_max']));
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

    /**
     * Splits the order into parcels while it is being prepared. Every unit of every item must be
     * in exactly one parcel; a single parcel is stored as the default (null).
     */
    public function updatePackages(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'packages' => ['required', 'array', 'min:1', 'max:'.Order::MAX_PACKAGES],
            'packages.*' => ['required', 'array', 'min:1'],
            'packages.*.*.order_item_id' => ['required', 'string'],
            'packages.*.*.quantity' => ['required', 'integer', 'min:1'],
        ]);

        if ($order->status !== OrderStatus::PROCESSING) {
            return ApiResponse::error('Paket hanya dapat diatur saat pesanan sedang diproses.', [], 422);
        }

        $ordered = $order->items()->pluck('quantity', 'id')->map(fn ($qty) => (int) $qty);
        $packed = [];
        $packages = [];

        foreach ($data['packages'] as $package) {
            // Merge repeated lines of the same item within one parcel.
            $lines = [];
            foreach ($package as $line) {
                $id = $line['order_item_id'];
                if (! $ordered->has($id)) {
                    return ApiResponse::error('Produk tidak termasuk dalam pesanan ini.', [], 422);
                }
                $lines[$id] = ($lines[$id] ?? 0) + (int) $line['quantity'];
                $packed[$id] = ($packed[$id] ?? 0) + (int) $line['quantity'];
            }

            $packages[] = collect($lines)
                ->map(fn (int $qty, string $id) => ['order_item_id' => $id, 'quantity' => $qty])
                ->values()->all();
        }

        foreach ($ordered as $id => $qty) {
            if (($packed[$id] ?? 0) !== $qty) {
                return ApiResponse::error('Jumlah produk di semua paket harus sama dengan jumlah pesanan.', [], 422);
            }
        }

        $order->update(['packages' => count($packages) > 1 ? $packages : null]);

        $order->load(['user', 'items', 'paymentMethod', 'shippingMethod']);

        return ApiResponse::success(new OrderResource($order), 'Paket pesanan berhasil disimpan.');
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
