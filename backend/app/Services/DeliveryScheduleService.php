<?php

namespace App\Services;

use App\Models\DeliveryHoliday;
use App\Models\DeliverySchedule;
use App\Models\Order;
use App\Models\ShippingMethod;
use App\Support\Enums\OrderStatus;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use RuntimeException;

/** Which delivery windows of a scheduled shipping method a buyer can still book. */
class DeliveryScheduleService
{
    /** Schedule times are entered by admins in local time. */
    public const TIMEZONE = 'Asia/Jakarta';

    /**
     * Upcoming days (only those the method runs on) with their windows, e.g.
     * [{date, day_label, date_label, holiday, slots: [{schedule_id, label, start_time, end_time, time_range, available, remaining, reason}]}].
     */
    public function upcoming(ShippingMethod $method): array
    {
        $schedules = $method->deliverySchedules()
            ->where('is_active', true)
            ->orderBy('start_time')
            ->orderBy('sort_order')
            ->get();

        $dates = $this->bookableDates($method);
        $booked = $this->bookedCounts($schedules->pluck('id'), $dates->first(), $dates->last());
        $holidays = $this->holidays($method, $dates->first(), $dates->last());

        return $dates
            ->map(function (Carbon $date, int $i) use ($method, $schedules, $booked, $holidays) {
                $holiday = $holidays[$date->toDateString()] ?? null;
                $slots = $schedules
                    ->filter(fn (DeliverySchedule $s) => $s->runsOn($date->dayOfWeekIso))
                    ->map(function (DeliverySchedule $s) use ($method, $date, $booked, $holiday) {
                        $count = $booked[$s->id.'|'.$date->toDateString()] ?? 0;
                        $reason = $this->unavailableReason($method, $s, $date, $count, $holiday);

                        return [
                            'schedule_id' => $s->id,
                            'label' => $s->label,
                            'start_time' => substr($s->start_time, 0, 5),
                            'end_time' => substr($s->end_time, 0, 5),
                            'time_range' => $s->timeRange(),
                            'available' => $reason === null,
                            'remaining' => $s->quota !== null ? max(0, $s->quota - $count) : null,
                            'reason' => $reason,
                        ];
                    })
                    ->values();

                return [
                    'date' => $date->toDateString(),
                    'day_label' => match ($i) {
                        0 => 'Hari ini',
                        1 => 'Besok',
                        default => $date->locale('id')->translatedFormat('l'),
                    },
                    'date_label' => $date->locale('id')->translatedFormat('j M'),
                    'holiday' => $holiday,
                    'slots' => $slots,
                ];
            })
            // Days the method has no window on would just be empty tabs.
            ->filter(fn (array $day) => $day['slots']->isNotEmpty())
            ->values()
            ->all();
    }

    /**
     * Locks the schedule and checks the window is still bookable; call inside the
     * checkout transaction so two buyers cannot take the last quota spot.
     *
     * @return array{date: string, slot: array} values to store on the order
     */
    public function reserve(ShippingMethod $method, string $scheduleId, string $date): array
    {
        $schedule = DeliverySchedule::whereKey($scheduleId)
            ->where('shipping_method_id', $method->id)
            ->lockForUpdate()
            ->first();

        if (! $schedule || ! $schedule->is_active) {
            throw new RuntimeException('Jadwal pengiriman yang dipilih tidak tersedia.');
        }

        $day = Carbon::createFromFormat('Y-m-d', $date, self::TIMEZONE)->startOfDay();
        $count = $this->bookedCounts(collect([$schedule->id]), $day, $day)[$schedule->id.'|'.$day->toDateString()] ?? 0;
        $holiday = $this->holidays($method, $day, $day)[$day->toDateString()] ?? null;

        if ($reason = $this->unavailableReason($method, $schedule, $day, $count, $holiday)) {
            throw new RuntimeException("Jadwal pengiriman {$schedule->label} ({$schedule->timeRange()}) {$reason}. Silakan pilih jadwal lain.");
        }

        return [
            'date' => $day->toDateString(),
            'slot' => [
                'label' => $schedule->label,
                'start_time' => substr($schedule->start_time, 0, 5),
                'end_time' => substr($schedule->end_time, 0, 5),
            ],
        ];
    }

    private function unavailableReason(ShippingMethod $method, DeliverySchedule $schedule, Carbon $date, int $booked, ?string $holiday): ?string
    {
        $dates = $this->bookableDates($method);

        if ($date->lt($dates->first()) || $date->gt($dates->last()) || ! $schedule->runsOn($date->dayOfWeekIso)) {
            return 'tidak tersedia di tanggal ini';
        }

        if ($holiday !== null) {
            return "libur ({$holiday})";
        }

        $closesAt = $date->copy()->setTimeFromTimeString($schedule->start_time)->subMinutes($schedule->cutoff_minutes);
        if ($this->now()->gte($closesAt)) {
            return 'sudah ditutup';
        }

        if ($schedule->quota !== null && $booked >= $schedule->quota) {
            return 'sudah penuh';
        }

        return null;
    }

    /** Today through today + (schedule_days_ahead - 1). */
    private function bookableDates(ShippingMethod $method): Collection
    {
        $today = $this->now()->startOfDay();
        $days = max(1, min(60, (int) ($method->schedule_days_ahead ?: 1)));

        return collect(range(0, $days - 1))->map(fn ($i) => $today->copy()->addDays($i));
    }

    /** Holiday name per Y-m-d, own holidays winning over global ones. */
    private function holidays(ShippingMethod $method, Carbon $from, Carbon $to): array
    {
        return DeliveryHoliday::query()
            ->forMethod($method->id)
            ->whereBetween('date', [$from->toDateString(), $to->toDateString()])
            ->orderByRaw('shipping_method_id is null desc')
            ->get()
            ->mapWithKeys(fn (DeliveryHoliday $h) => [$h->date->toDateString() => $h->name])
            ->all();
    }

    /** Non-cancelled orders per "scheduleId|Y-m-d". */
    private function bookedCounts(Collection $scheduleIds, Carbon $from, Carbon $to): array
    {
        if ($scheduleIds->isEmpty()) {
            return [];
        }

        return Order::query()
            ->whereIn('delivery_schedule_id', $scheduleIds)
            ->whereBetween('delivery_date', [$from->toDateString(), $to->toDateString()])
            ->where('status', '!=', OrderStatus::CANCELLED)
            ->selectRaw('delivery_schedule_id, delivery_date, count(*) as total')
            ->groupBy('delivery_schedule_id', 'delivery_date')
            ->get()
            ->mapWithKeys(fn ($row) => [$row->delivery_schedule_id.'|'.Carbon::parse($row->delivery_date)->toDateString() => (int) $row->total])
            ->all();
    }

    private function now(): Carbon
    {
        return Carbon::now(self::TIMEZONE);
    }
}
