'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi, apiRequest, apiRequestFull } from '../../../lib/api';
import OrderDetailModal from './OrderDetailModal';
import { useOrderTabs, rupiah } from './orderShared';
import { formatDate, formatDateTime, todayWib } from '../../../lib/date';
import { WaitTimer } from '../../../components/orders/InstantOrders';
import { useInstantOrders, useNow } from '../../../lib/instantOrders';
import { onAdminChange } from '../../../lib/realtime';
import { ShippingMethod } from '../../../types';
import { ShoppingBag, Loader2, PackageCheck, Search, ChevronLeft, ChevronRight, X } from 'lucide-react';

/** Not yet handed to the courier: the instant-order timer runs (same as the backend's AWAITING_DISPATCH). */
const AWAITING_DISPATCH = ['pending', 'processing', 'ready'];

/** Table filters, sent as-is to GET /admin/orders and /admin/orders/counts (the status tab is separate). */
type Filters = {
  search: string;
  date_from: string;
  date_to: string;
  shipping_method_id: string;
  total_min: string;
  total_max: string;
};

const NO_FILTERS: Filters = { search: '', date_from: '', date_to: '', shipping_method_id: '', total_min: '', total_max: '' };

const filterInput = 'rounded-lg border border-slate-200 bg-white px-2.5 py-2 text-sm font-normal outline-none focus:border-emerald-500';

/** How late past the estimate: "12 menit", "1 jam 5 menit", "7 hari 4 jam". */
function lateText(ms: number): string {
  const minutes = Math.max(1, Math.floor(ms / 60_000));
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  if (days) return `${days} hari ${hours} jam`;
  if (hours) return `${hours} jam ${minutes % 60} menit`;
  return `${minutes} menit`;
}

export default function AdminOrdersPage() {
  const TABS = useOrderTabs();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [orders, setOrders] = useState<any[]>([]);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [status, setStatus] = useState('all');
  const [filters, setFilters] = useState<Filters>(NO_FILTERS);
  const [applied, setApplied] = useState<Filters>(NO_FILTERS);
  const [shippingMethods, setShippingMethods] = useState<ShippingMethod[]>([]);
  const [page, setPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const reqId = useRef(0);

  // Debounce typing in the filters; a change restarts from page 1.
  useEffect(() => {
    const t = setTimeout(() => {
      setApplied(filters);
      setPage(1);
    }, 350);
    return () => clearTimeout(t);
  }, [filters]);

  useEffect(() => {
    adminApi.getShippingMethods().then(setShippingMethods).catch(() => {});
  }, []);

  const setFilter = (key: keyof Filters, value: string) => setFilters((f) => ({ ...f, [key]: value }));
  const hasFilters = Object.values(applied).some((v) => v.trim() !== '');

  /** Query string of the applied filters, shared by the table and the tab counts. */
  const filterQuery = useMemo(() => {
    const params = new URLSearchParams();
    Object.entries(applied).forEach(([key, value]) => value.trim() && params.set(key, value.trim()));
    return params.toString();
  }, [applied]);

  const fetchOrders = useCallback(async () => {
    const id = ++reqId.current;
    setLoading(true);
    const params = new URLSearchParams(filterQuery);
    params.set('page', String(page));
    if (status !== 'all') params.set('status', status);
    try {
      const res = await apiRequestFull<any[]>(`/admin/orders?${params.toString()}`);
      if (id !== reqId.current) return;
      setOrders(Array.isArray(res.data) ? res.data : []);
      setLastPage(res.meta?.last_page ?? 1);
    } catch {
      if (id !== reqId.current) return;
      setOrders([]);
      setLastPage(1);
    } finally {
      if (id === reqId.current) setLoading(false);
    }
  }, [page, status, filterQuery]);

  useEffect(() => {
    fetchOrders();
  }, [fetchOrders]);

  // Tab badges follow the filters but not the selected tab.
  const fetchCounts = useCallback(() => {
    apiRequest<Record<string, number>>(`/admin/orders/counts?${filterQuery}`)
      .then(setCounts)
      .catch(() => {});
  }, [filterQuery]);

  useEffect(fetchCounts, [fetchCounts]);

  // Realtime: refresh the table and tab counts whenever an order changes (status set in the admin app).
  useEffect(
    () =>
      onAdminChange('admin.orders', () => {
        void fetchOrders();
        fetchCounts();
      }),
    [fetchOrders, fetchCounts],
  );

  // Ship-by limit for the instant-order timers (shared store, also used by the menu badge).
  const { queue } = useInstantOrders();
  const dispatchMinutes = queue?.dispatch_minutes ?? null;
  const now = useNow();

  const selectTab = (value: string) => {
    setStatus(value);
    setPage(1);
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <ShoppingBag className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">Pesanan</h2>
          </div>
          <p className="mt-1 text-xs md:text-sm text-slate-500">
            Monitoring pesanan masuk dari pembeli berdasarkan status pesanan.
          </p>
        </div>

        <div className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="space-y-3 border-b border-slate-100 p-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                value={filters.search}
                onChange={(e) => setFilter('search', e.target.value)}
                placeholder="Cari nomor pesanan / nama pembeli"
                className="w-full rounded-xl border border-slate-200 py-2 pl-9 pr-3 text-sm outline-none focus:border-emerald-500"
              />
            </div>
            {/* One filter per column with fixed values; Waktu Proses / Estimasi keep changing, so none. */}
            <div className="flex flex-wrap items-end gap-3">
              <label className="text-xs font-semibold text-slate-600">
                Tanggal Pesanan
                <div className="mt-1 flex items-center gap-1.5">
                  <input
                    type="date"
                    value={filters.date_from}
                    max={filters.date_to || todayWib()}
                    onChange={(e) => setFilter('date_from', e.target.value)}
                    aria-label="Tanggal pesanan dari"
                    className={filterInput}
                  />
                  <span className="text-slate-400">–</span>
                  <input
                    type="date"
                    value={filters.date_to}
                    min={filters.date_from || undefined}
                    max={todayWib()}
                    onChange={(e) => setFilter('date_to', e.target.value)}
                    aria-label="Tanggal pesanan sampai"
                    className={filterInput}
                  />
                </div>
              </label>
              <label className="text-xs font-semibold text-slate-600">
                Pengiriman
                <select
                  value={filters.shipping_method_id}
                  onChange={(e) => setFilter('shipping_method_id', e.target.value)}
                  className={`mt-1 block ${filterInput}`}
                >
                  <option value="">Semua metode</option>
                  {shippingMethods.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="text-xs font-semibold text-slate-600">
                Total (Rp)
                <div className="mt-1 flex items-center gap-1.5">
                  <input
                    type="number"
                    min={0}
                    step={1000}
                    value={filters.total_min}
                    onChange={(e) => setFilter('total_min', e.target.value)}
                    placeholder="Min"
                    aria-label="Total minimal"
                    className={`w-28 ${filterInput}`}
                  />
                  <span className="text-slate-400">–</span>
                  <input
                    type="number"
                    min={0}
                    step={1000}
                    value={filters.total_max}
                    onChange={(e) => setFilter('total_max', e.target.value)}
                    placeholder="Maks"
                    aria-label="Total maksimal"
                    className={`w-28 ${filterInput}`}
                  />
                </div>
              </label>
              {Object.values(filters).some((v) => v !== '') && (
                <button
                  type="button"
                  onClick={() => setFilters(NO_FILTERS)}
                  className="inline-flex items-center gap-1 rounded-lg px-2.5 py-2 text-xs font-semibold text-slate-500 hover:bg-slate-100 hover:text-slate-700"
                >
                  <X className="h-3.5 w-3.5" /> Reset filter
                </button>
              )}
            </div>
          </div>

          <div className="flex gap-1 overflow-x-auto border-b border-slate-100 px-2">
            {TABS.map((t) => {
              const active = status === t.value;
              const count = counts[t.value];
              return (
                <button
                  key={t.value}
                  onClick={() => selectTab(t.value)}
                  className={`flex shrink-0 items-center gap-1.5 border-b-2 px-3 py-3 text-sm transition-colors ${
                    active
                      ? 'border-emerald-600 font-bold text-emerald-700'
                      : 'border-transparent font-medium text-slate-500 hover:text-slate-700'
                  }`}
                >
                  {t.label}
                  <span
                    className={`min-w-[22px] rounded-full px-1.5 py-0.5 text-center text-[11px] font-bold ${
                      active ? 'bg-emerald-600 text-white' : count ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-400'
                    }`}
                  >
                    {count === undefined ? '·' : count > 999 ? '999+' : count}
                  </span>
                </button>
              );
            })}
          </div>

          {loading ? (
            <div className="py-12 flex justify-center text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : orders.length === 0 ? (
            <div className="py-16 text-center text-slate-400">
              <PackageCheck className="h-10 w-10 mx-auto text-slate-300 mb-2" />
              <p className="text-sm font-medium">
                {hasFilters
                  ? 'Tidak ada pesanan yang cocok dengan filter.'
                  : status === 'all'
                  ? 'Belum ada pesanan.'
                  : `Tidak ada pesanan "${TABS.find((t) => t.value === status)?.label}".`}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                  <tr>
                    <th className="py-3 px-4">No. Pesanan</th>
                    <th className="py-3 px-4">Tanggal Pesanan</th>
                    <th className="py-3 px-4">Pembeli</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Pengiriman</th>
                    <th className="py-3 px-4">Waktu Proses</th>
                    <th className="py-3 px-4">Estimasi</th>
                    <th className="py-3 px-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {orders.map((o) => {
                    const tab = TABS.find((t) => t.value === o.status);
                    // Instant orders not yet shipped get the running timer and the estimate.
                    const timed = !o.delivery_date && AWAITING_DISPATCH.includes(o.status) && dispatchMinutes !== null;
                    const late = timed ? now - Date.parse(o.created_at) - dispatchMinutes * 60_000 : 0;
                    return (
                      <tr
                        key={o.id}
                        onClick={() => setSelectedId(String(o.id))}
                        className="cursor-pointer transition-colors hover:bg-emerald-50/40"
                      >
                        <td className="py-3 px-4">
                          <p className="font-bold text-slate-900">{o.order_number}</p>
                        </td>
                        <td className="whitespace-nowrap py-3 px-4 text-slate-600">{formatDateTime(o.created_at)}</td>
                        <td className="py-3 px-4">
                          <p className="font-semibold text-slate-800">{o.user?.name ?? '-'}</p>
                          {o.items_count != null && <p className="text-xs text-slate-500">{o.items_count} item</p>}
                        </td>
                        <td className="py-3 px-4">
                          <span
                            className={`whitespace-nowrap rounded-full px-2.5 py-1 text-[11px] font-bold ${
                              tab?.badge ?? 'bg-slate-100 text-slate-600'
                            }`}
                          >
                            {tab?.label ?? o.status}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                          <p className="font-semibold text-slate-800">{o.shipping_method?.name ?? o.delivery_method ?? '-'}</p>
                          <p className="whitespace-nowrap text-xs text-slate-500">
                            {o.delivery_date
                              ? `${formatDate(o.delivery_date)}${o.delivery_slot ? ` · ${o.delivery_slot}` : ''}`
                              : 'Instan'}
                          </p>
                        </td>
                        <td className="py-3 px-4">
                          {timed ? (
                            <WaitTimer createdAt={o.created_at} dispatchMinutes={dispatchMinutes} now={now} className="inline-block" />
                          ) : (
                            <span className="text-slate-300">—</span>
                          )}
                        </td>
                        <td className="py-3 px-4">
                          {o.delivery_date ? (
                            <span className="whitespace-nowrap text-xs text-slate-500">Sesuai jadwal</span>
                          ) : timed ? (
                            <>
                              <p className="whitespace-nowrap font-semibold text-slate-800">{dispatchMinutes} menit</p>
                              {late > 0 && (
                                <p className="whitespace-nowrap text-xs font-semibold text-rose-600">Telat {lateText(late)}</p>
                              )}
                            </>
                          ) : (
                            <span className="text-slate-300">—</span>
                          )}
                        </td>
                        <td className="whitespace-nowrap py-3 px-4 text-right font-extrabold text-slate-900">
                          {rupiah(o.grand_total)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          {lastPage > 1 && (
            <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm">
              <button
                disabled={page <= 1 || loading}
                onClick={() => setPage((p) => p - 1)}
                className="flex items-center gap-1 rounded-lg border border-slate-200 px-3 py-1.5 font-medium text-slate-600 disabled:opacity-40"
              >
                <ChevronLeft className="h-4 w-4" /> Sebelumnya
              </button>
              <span className="text-xs text-slate-500">
                Halaman {page} dari {lastPage}
              </span>
              <button
                disabled={page >= lastPage || loading}
                onClick={() => setPage((p) => p + 1)}
                className="flex items-center gap-1 rounded-lg border border-slate-200 px-3 py-1.5 font-medium text-slate-600 disabled:opacity-40"
              >
                Berikutnya <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          )}
        </div>
      </div>
      {selectedId && <OrderDetailModal orderId={selectedId} onClose={() => setSelectedId(null)} />}
    </AdminLayout>
  );
}
