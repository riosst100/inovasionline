'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { CalendarClock, ExternalLink } from 'lucide-react';
import { apiRequest } from '../../lib/api';
import { useLabels } from '../../lib/labels';
import { onAdminChange } from '../../lib/realtime';
import { rupiah } from '../../lib/wallet';
import { useNow, wibParts } from '../../lib/date';
import { ScheduledOrders } from '../../types';

const DAYS = [
  { label: 'Hari ini', offset: 0 },
  { label: 'Besok', offset: 1 },
];

/** Current WIB time as "HH:MM", to mark today's running slot. */
const wibClock = (now: number) => wibParts(now).time;

/** Dashboard panel: scheduled orders of today / tomorrow, filterable per delivery slot. Live via `admin.orders`. */
export function ScheduledOrdersPanel() {
  const { get } = useLabels();
  const now = useNow(30_000);
  const [offset, setOffset] = useState(0);
  const [slot, setSlot] = useState<string>('all');
  const [data, setData] = useState<ScheduledOrders | null>(null);

  // Delivery date in WIB; empty until the clock is read after mount.
  const date = now ? wibParts(now + offset * 86_400_000).date : '';
  const load = useCallback(() => {
    if (!date) return;
    apiRequest<ScheduledOrders>(`/admin/orders/scheduled?date=${date}`)
      .then(setData)
      .catch(() => setData((d) => d ?? { date, count: 0, slots: [], orders: [] }));
  }, [date]);

  useEffect(load, [load]);
  useEffect(() => onAdminChange('admin.orders', load), [load]);

  const current = data?.date === date ? data : null;
  const clock = wibClock(now);
  const slotOf = (id: string | null) => current?.slots.find((s) => s.id === id);
  const orders = current?.orders.filter((o) => slot === 'all' || o.delivery_schedule_id === slot) ?? [];

  const chip = (active: boolean) =>
    `inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
      active ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
    }`;

  return (
    <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-5 py-3.5">
        <div>
          <h3 className="flex items-center gap-1.5 text-base font-bold text-slate-900">
            <CalendarClock className="h-4 w-4 text-blue-500" /> Pesanan Terjadwal
          </h3>
          <p className="text-xs text-slate-500">Pesanan dengan jadwal kirim, per slot jam pengiriman.</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex rounded-lg border border-slate-200 p-0.5 text-xs font-semibold">
            {DAYS.map((d) => (
              <button
                key={d.offset}
                type="button"
                onClick={() => {
                  setOffset(d.offset);
                  setSlot('all');
                }}
                className={`rounded-md px-3 py-1.5 ${offset === d.offset ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
              >
                {d.label}
              </button>
            ))}
          </div>
          <Link
            href="/dashboard/orders"
            title="Buka halaman Pesanan"
            aria-label="Buka halaman Pesanan"
            className="rounded-lg p-1.5 text-slate-500 transition-colors hover:bg-black/5 hover:text-emerald-600"
          >
            <ExternalLink className="h-4 w-4" />
          </Link>
        </div>
      </div>

      {!current ? (
        <div className="space-y-2 p-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="skeleton h-10" />
          ))}
        </div>
      ) : (
        <>
          <div className="flex flex-wrap gap-2 border-b border-slate-100 px-4 py-3">
            <button type="button" onClick={() => setSlot('all')} className={chip(slot === 'all')}>
              Semua jam <b className="tabular-nums">{current.count}</b>
            </button>
            {current.slots.map((s) => {
              const [start, end] = s.time_range.split(' - ');
              const running = offset === 0 && clock >= start && clock < end;
              const full = s.quota !== null && s.count >= s.quota;
              return (
                <button
                  key={s.id}
                  type="button"
                  onClick={() => setSlot(s.id)}
                  title={s.shipping_method ?? undefined}
                  className={chip(slot === s.id)}
                >
                  {running && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-500" title="Sedang berjalan" />}
                  {s.label} <span className="text-slate-400">{s.time_range}</span>
                  <b className={`tabular-nums ${full ? 'text-amber-600' : s.count === 0 ? 'text-slate-400' : ''}`}>
                    {s.count}
                    {s.quota !== null && <span className="font-normal text-slate-400">/{s.quota}</span>}
                  </b>
                </button>
              );
            })}
          </div>

          {orders.length === 0 ? (
            <p className="py-8 text-center text-sm text-slate-400">
              Tidak ada pesanan terjadwal {slot === 'all' ? '' : 'di slot ini '}untuk {offset === 0 ? 'hari ini' : 'besok'}.
            </p>
          ) : (
            <ul className="max-h-96 divide-y divide-slate-100 overflow-y-auto">
              {orders.map((o) => {
                const status = get('order_status', o.status);
                const s = slotOf(o.delivery_schedule_id);
                return (
                  <li key={o.id} className="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 px-4 py-2.5">
                    <div className="min-w-0">
                      <p className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                        {o.order_number}
                        <span className={`rounded-md px-1.5 py-0.5 text-[10px] font-semibold ${status.badge}`}>{status.label}</span>
                      </p>
                      <p className="truncate text-xs text-slate-500">
                        {o.customer ?? '-'} · {rupiah(o.grand_total)}
                      </p>
                    </div>
                    {s && (
                      <span className="shrink-0 rounded-lg bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700 ring-1 ring-blue-100">
                        {s.label} · {s.time_range}
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </>
      )}
    </section>
  );
}
