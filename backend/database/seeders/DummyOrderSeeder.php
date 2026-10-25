<?php

namespace Database\Seeders;

use App\Models\DeliverySchedule;
use App\Models\Order;
use App\Models\Product;
use App\Models\ShippingMethod;
use App\Models\User;
use App\Support\Enums\OrderStatus;
use App\Support\Enums\PaymentStatus;
use App\Support\Enums\UserRole;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Demo orders for the admin dashboard panels (Pesanan Instant / Pesanan Terjadwal): instant orders
 * of different ages (fresh, due soon, late) and scheduled orders for today and tomorrow in every slot.
 * Not part of DatabaseSeeder; run on a dev DB with
 *   php artisan db:seed --class=DummyOrderSeeder
 * Every order number starts with DUMMY-; rerunning replaces the previous dummy orders.
 */
class DummyOrderSeeder extends Seeder
{
    public const PREFIX = 'DUMMY-';

    private const TIMEZONE = 'Asia/Jakarta';

    public function run(): void
    {
        DB::transaction(function () {
            Order::query()->where('order_number', 'like', self::PREFIX.'%')->each(function (Order $order) {
                $order->items()->delete();
                $order->delete();
            });

            $buyers = $this->buyers();
            $products = Product::query()->where('status', 'active')->inRandomOrder()->limit(8)->get();
            $express = ShippingMethod::query()->where('type', 'io_express')->first();
            $sameDay = ShippingMethod::query()->where('type', 'io_same_day')->first();

            // Instant: [status, minutes ago]; with the default 30-minute limit these read as
            // fresh, due soon, being packed, and late.
            foreach ([
                [OrderStatus::PENDING, 3],
                [OrderStatus::PENDING, 24],
                [OrderStatus::PROCESSING, 12],
                [OrderStatus::READY, 45],
            ] as $i => [$status, $minutesAgo]) {
                $this->order($buyers[$i % count($buyers)], $products, $status, now()->subMinutes($minutesAgo), $express);
            }

            // Scheduled: every slot that runs today / tomorrow, a few orders each.
            $slots = DeliverySchedule::query()->where('is_active', true)->orderBy('start_time')->get();
            foreach ([0 => [OrderStatus::PROCESSING, OrderStatus::READY, OrderStatus::ON_DELIVERY, OrderStatus::COMPLETED], 1 => [OrderStatus::PENDING, OrderStatus::PENDING, OrderStatus::PROCESSING]] as $offset => $statuses) {
                $date = now(self::TIMEZONE)->addDays($offset);
                foreach ($slots->filter(fn (DeliverySchedule $s) => $s->runsOn($date->dayOfWeekIso))->values() as $n => $slot) {
                    foreach (array_slice($statuses, 0, 1 + ($n + $offset) % count($statuses)) as $k => $status) {
                        $this->order(
                            $buyers[($n + $k) % count($buyers)],
                            $products,
                            $status,
                            now()->subHours(2 + $k),
                            $slot->shippingMethod ?? $sameDay,
                            $slot,
                            $date->toDateString(),
                        );
                    }
                }
            }
        });

        $count = Order::query()->where('order_number', 'like', self::PREFIX.'%')->count();
        $this->command?->info("{$count} dummy orders seeded (order numbers start with ".self::PREFIX.').');
    }

    /** Existing customers, or a few demo buyers when there are none. */
    private function buyers(): array
    {
        $buyers = User::query()->where('role', UserRole::CUSTOMER)->limit(5)->get()->all();
        if ($buyers) {
            return $buyers;
        }

        return collect(['Budi Hartono', 'Siti Aminah', 'Andi Wijaya'])->map(fn (string $name, int $i) => User::query()->firstOrCreate(
            ['email' => 'pembeli.dummy'.($i + 1).'@example.test'],
            ['name' => $name, 'password' => Hash::make(Str::random(32)), 'role' => UserRole::CUSTOMER],
        ))->all();
    }

    private function order(
        User $buyer,
        $products,
        OrderStatus $status,
        Carbon $createdAt,
        ?ShippingMethod $method,
        ?DeliverySchedule $slot = null,
        ?string $deliveryDate = null,
    ): void {
        $lines = $products->isEmpty()
            ? collect([['product' => null, 'name' => 'Produk Dummy', 'price' => 25000, 'qty' => 2]])
            : $products->random(min(rand(1, 3), $products->count()))->map(fn (Product $p) => [
                'product' => $p,
                'name' => $p->name,
                'price' => (float) ($p->sale_price ?: $p->regular_price),
                'qty' => rand(1, 3),
            ]);
        $subtotal = $lines->sum(fn ($l) => $l['price'] * $l['qty']);
        $shipping = (float) ($method?->base_fee ?? 10000);

        $order = Order::create([
            'order_number' => self::PREFIX.strtoupper(Str::random(8)),
            'user_id' => $buyer->id,
            'shipping_method_id' => $method?->id,
            'delivery_schedule_id' => $slot?->id,
            'subtotal' => $subtotal,
            'discount_total' => 0,
            'shipping_fee' => $shipping,
            'service_fee' => 0,
            'tax_total' => 0,
            'grand_total' => $subtotal + $shipping,
            'status' => $status,
            'payment_status' => PaymentStatus::PAID,
            'paid_at' => $createdAt,
            'delivery_method' => $method?->type ?? ($slot ? 'io_same_day' : 'io_express'),
            'delivery_address' => [
                'recipient_name' => $buyer->name,
                'address_line' => 'Jl. Contoh No. '.rand(1, 99).', Jakarta Selatan',
                'city' => 'Jakarta Selatan',
            ],
            'delivery_date' => $deliveryDate,
            'delivery_slot' => $slot?->timeRange(),
            'status_history' => [['status' => $status->value, 'at' => $createdAt->toIso8601String(), 'by' => 'seeder']],
            'completed_at' => $status === OrderStatus::COMPLETED ? now() : null,
        ]);
        $order->forceFill(['created_at' => $createdAt])->save();

        foreach ($lines as $line) {
            $order->items()->create([
                'product_id' => $line['product']?->id,
                'product_name' => $line['name'],
                'product_sku' => $line['product']?->sku,
                'unit_price' => $line['price'],
                'unit_cost' => $line['product']?->cost_price,
                'quantity' => $line['qty'],
                'discount_amount' => 0,
                'line_total' => $line['price'] * $line['qty'],
            ]);
        }
    }
}
