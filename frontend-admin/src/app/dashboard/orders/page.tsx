'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest, apiRequestFull } from '../../../lib/api';
import OrderDetailModal from './OrderDetailModal';
import { useOrderTabs, PAYMENT_LABELS, formatDateTime, rupiah } from './orderShared';
import { ShoppingBag, Loader2, PackageCheck, Search, User, ChevronLeft, ChevronRight } from 'lucide-react';

export default function AdminOrdersPage() {
  const TABS = useOrderTabs();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [orders, setOrders] = useState<any[]>([]);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [status, setStatus] = useState('all');
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const reqId = useRef(0);

  // Debounce the search box; a new query restarts from page 1.
  useEffect(() => {
    const t = setTimeout(() => {
      setQuery(search.trim());
      setPage(1);
    }, 350);
    return () => clearTimeout(t);
  }, [search]);

  const fetchOrders = useCallback(async () => {
    const id = ++reqId.current;
    setLoading(true);
    const params = new URLSearchParams({ page: String(page) });
    if (status !== 'all') params.set('status', status);
    if (query) params.set('search', query);
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
  }, [page, status, query]);

  useEffect(() => {
    fetchOrders();
  }, [fetchOrders]);

  // Tab badges follow the search query but not the selected tab.
  useEffect(() => {
    const params = new URLSearchParams();
    if (query) params.set('search', query);
    apiRequest<Record<string, number>>(`/admin/orders/counts?${params.toString()}`)
      .then(setCounts)
      .catch(() => {});
  }, [query]);

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
          <div className="p-4 border-b border-slate-100">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Cari nomor pesanan / nama pembeli"
                className="w-full rounded-xl border border-slate-200 py-2 pl-9 pr-3 text-sm outline-none focus:border-emerald-500"
              />
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
                      active ? 'bg-emerald-600 text-white' : count ? t.badge : 'bg-slate-100 text-slate-400'
                    }`}
                  >
                    {count === undefined ? '·' : count > 999 ? '999+' : count}
                  </span>
                </button>
              );
            })}
          </div>

          <div className="p-4">
            {loading ? (
              <div className="py-12 flex justify-center text-emerald-600">
                <Loader2 className="h-6 w-6 animate-spin" />
              </div>
            ) : orders.length === 0 ? (
              <div className="py-16 text-center text-slate-400">
                <PackageCheck className="h-10 w-10 mx-auto text-slate-300 mb-2" />
                <p className="text-sm font-medium">
                  {query
                    ? 'Tidak ada pesanan yang cocok.'
                    : status === 'all'
                    ? 'Belum ada pesanan.'
                    : `Tidak ada pesanan "${TABS.find((t) => t.value === status)?.label}".`}
                </p>
              </div>
            ) : (
              <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
                {orders.map((o) => {
                  const tab = TABS.find((t) => t.value === o.status);
                  const pay = PAYMENT_LABELS[o.payment_status] ?? {
                    label: o.payment_status,
                    cls: 'bg-slate-100 text-slate-600',
                  };
                  return (
                    <div
                      key={o.id}
                      onClick={() => setSelectedId(String(o.id))}
                      className="cursor-pointer rounded-xl border border-slate-200 bg-white p-4 transition-colors hover:border-emerald-400"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-bold text-slate-900">{o.order_number}</p>
                          <p className="text-xs text-slate-500">{formatDateTime(o.created_at)}</p>
                        </div>
                        <span
                          className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-bold ${
                            tab?.badge ?? 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {tab?.label ?? o.status}
                        </span>
                      </div>

                      <div className="mt-3 flex items-center gap-1.5 border-t border-slate-100 pt-3 text-xs text-slate-700">
                        <User className="h-4 w-4 shrink-0 text-slate-400" />
                        <span className="min-w-0 flex-1 truncate font-semibold">{o.user?.name ?? '-'}</span>
                        {o.items_count != null && <span className="text-slate-500">{o.items_count} item</span>}
                      </div>

                      <div className="mt-3 flex items-end justify-between gap-2">
                        <div className="min-w-0">
                          <span className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${pay.cls}`}>
                            {pay.label}
                          </span>
                          {o.payment_method?.name && (
                            <p className="mt-1 truncate text-xs text-slate-500">{o.payment_method.name}</p>
                          )}
                        </div>
                        <div className="text-right">
                          <p className="text-[11px] text-slate-400">Total</p>
                          <p className="text-sm font-extrabold text-emerald-700">{rupiah(o.grand_total)}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

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
