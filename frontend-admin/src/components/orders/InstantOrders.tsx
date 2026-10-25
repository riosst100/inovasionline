'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { AlarmClock, BellRing, ChevronDown, ExternalLink, Timer, Volume2, VolumeX, Zap } from 'lucide-react';
import { useLabels } from '../../lib/labels';
import { rupiah } from '../../lib/wallet';
import {
  formatClock,
  setInstantOrderSound,
  unpacked,
  urgency,
  Urgency,
  useInstantOrders,
  useNow,
} from '../../lib/instantOrders';
import { InstantOrderQueue } from '../../types';

const TONE: Record<Urgency, { row: string; badge: string }> = {
  late: { row: 'bg-rose-50/60', badge: 'bg-rose-50 text-rose-700 ring-1 ring-rose-200 animate-pulse' },
  soon: { row: 'bg-orange-50/60', badge: 'bg-orange-50 text-orange-700 ring-1 ring-orange-200' },
  ok: { row: '', badge: 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200' },
};

/**
 * Ticking timer box: time since the order was placed, green → orange (half the ship-by limit)
 * → red (past it). Shared by the dashboard panel and the orders table.
 */
export function WaitTimer({
  createdAt,
  dispatchMinutes,
  now,
  className = '',
}: {
  createdAt: string;
  dispatchMinutes: number;
  now: number;
  className?: string;
}) {
  const created = Date.parse(createdAt);
  const level = urgency(new Date(created + dispatchMinutes * 60_000).toISOString(), dispatchMinutes, now);

  return (
    <div
      className={`min-w-[88px] shrink-0 rounded-lg px-2.5 py-1.5 text-right ${TONE[level].badge} ${className}`}
      title={`Lama menunggu sejak pesanan dibuat (batas kirim ${dispatchMinutes} menit)`}
    >
      <p className="flex items-center justify-end gap-1 font-mono text-sm font-bold tabular-nums">
        <Timer className="h-3.5 w-3.5 opacity-70" />
        {formatClock(now - created)}
      </p>
    </div>
  );
}

/** Waiting instant orders with their WaitTimer; the row is tinted by the same urgency. */
export function InstantOrderList({ queue, now }: { queue: InstantOrderQueue; now: number }) {
  const { get } = useLabels();

  return (
    <ul className="divide-y divide-slate-100">
      {queue.orders.map((o) => {
        const level = urgency(o.deadline_at, queue.dispatch_minutes, now);
        const status = get('order_status', o.status);
        return (
          <li key={o.id} className={`flex flex-wrap items-center justify-between gap-x-4 gap-y-2 px-4 py-2.5 ${TONE[level].row}`}>
            <div className="min-w-0">
              <p className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                {o.order_number}
                <span className={`rounded-md px-1.5 py-0.5 text-[10px] font-semibold ${status.badge}`}>{status.label}</span>
              </p>
              <p className="truncate text-xs text-slate-500">
                {o.customer ?? '-'} · {rupiah(o.grand_total)}
              </p>
            </div>
            <WaitTimer createdAt={o.created_at} dispatchMinutes={queue.dispatch_minutes} now={now} />
          </li>
        );
      })}
    </ul>
  );
}

function SoundToggle({ on, className = '' }: { on: boolean; className?: string }) {
  return (
    <button
      type="button"
      onClick={() => setInstantOrderSound(!on)}
      title={on ? 'Matikan suara notifikasi' : 'Nyalakan suara notifikasi'}
      aria-label={on ? 'Matikan suara notifikasi' : 'Nyalakan suara notifikasi'}
      className={`rounded-lg p-1.5 transition-colors hover:bg-black/5 ${className}`}
    >
      {on ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
    </button>
  );
}

/**
 * Global alert under the header on every admin page while instant orders wait to be shipped.
 * Red when one is past its deadline, orange when one is due soon.
 */
export function InstantOrderBanner() {
  const { queue, sound } = useInstantOrders();
  const now = useNow();
  const [open, setOpen] = useState(false);

  if (!queue || queue.count === 0) return null;

  const levels = queue.orders.map((o) => urgency(o.deadline_at, queue.dispatch_minutes, now));
  const late = levels.filter((l) => l === 'late').length;
  const next = queue.orders.find((o) => Date.parse(o.deadline_at) >= now);
  const waiting = unpacked(queue);
  // An order nobody has started packing is at least orange, even with time to spare.
  const level: Urgency = late > 0 ? 'late' : waiting > 0 || levels.includes('soon') ? 'soon' : 'ok';
  const style = {
    late: 'border-rose-200 bg-rose-50 text-rose-900',
    soon: 'border-orange-200 bg-orange-50 text-orange-900',
    ok: 'border-emerald-200 bg-emerald-50 text-emerald-900',
  }[level];

  return (
    <div className="px-4 pt-4 sm:px-6 lg:px-8">
      <div className={`mx-auto max-w-7xl overflow-hidden rounded-xl border shadow-sm ${style}`}>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-2.5 text-sm">
          {level === 'late' || waiting > 0 ? (
            <BellRing className="h-5 w-5 shrink-0 animate-bounce" />
          ) : (
            <AlarmClock className="h-5 w-5 shrink-0" />
          )}
          <p className="min-w-0 flex-1">
            <b>{queue.count} pesanan instan</b> menunggu dikirim
            {waiting > 0 && (
              <>
                {' '}· <b>{waiting} belum dikemas</b>
              </>
            )}
            {late > 0 && <> · <b>{late} terlambat</b></>}
            {next && (
              <>
                {' '}· berikutnya <b>{next.order_number}</b> harus dikirim dalam{' '}
                <b className="font-mono tabular-nums">{formatClock(Date.parse(next.deadline_at) - now)}</b>
              </>
            )}
            <span className="opacity-75"> (batas {queue.dispatch_minutes} menit)</span>
          </p>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setOpen(!open)}
              aria-expanded={open}
              className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold hover:bg-black/5"
            >
              {open ? 'Tutup' : 'Lihat'} <ChevronDown className={`h-3.5 w-3.5 transition-transform ${open ? 'rotate-180' : ''}`} />
            </button>
            <Link href="/dashboard/orders" className="rounded-lg px-2 py-1 text-xs font-semibold underline-offset-2 hover:underline">
              Buka Pesanan
            </Link>
            <SoundToggle on={sound} />
          </div>
        </div>
        {open && (
          <div className="max-h-80 overflow-y-auto bg-white text-slate-900">
            <InstantOrderList queue={queue} now={now} />
          </div>
        )}
      </div>
    </div>
  );
}

/** Dashboard panel: every waiting instant order with its timers. */
export function InstantOrdersPanel() {
  const { queue, sound } = useInstantOrders();
  const now = useNow();

  return (
    <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
      <div className="flex items-center justify-between border-b border-slate-100 px-5 py-3.5">
        <div>
          <h3 className="flex items-center gap-1.5 text-base font-bold text-slate-900">
            <Zap className="h-4 w-4 text-amber-500" /> Pesanan Instant
          </h3>
          <p className="text-xs text-slate-500">
            Harus dikirim maksimal {queue?.dispatch_minutes ?? '…'} menit setelah pesanan dibuat. Paling lama menunggu di atas.
          </p>
        </div>
        <div className="flex items-center gap-1 text-slate-500">
          <SoundToggle on={sound} />
          <Link
            href="/dashboard/orders"
            title="Buka halaman Pesanan"
            aria-label="Buka halaman Pesanan"
            className="rounded-lg p-1.5 transition-colors hover:bg-black/5 hover:text-emerald-600"
          >
            <ExternalLink className="h-4 w-4" />
          </Link>
        </div>
      </div>
      {!queue ? (
        <div className="space-y-2 p-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="skeleton h-10" />
          ))}
        </div>
      ) : queue.count === 0 ? (
        <p className="py-8 text-center text-sm text-slate-400">Tidak ada pesanan instan yang menunggu dikirim.</p>
      ) : (
        <>
          <InstantOrderList queue={queue} now={now} />
          {queue.count > queue.orders.length && (
            <p className="border-t border-slate-100 px-4 py-2 text-xs text-slate-500">
              +{queue.count - queue.orders.length} pesanan lainnya di halaman Pesanan.
            </p>
          )}
        </>
      )}
    </section>
  );
}
