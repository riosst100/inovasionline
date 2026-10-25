'use client';

import React, { Suspense, use, useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { io } from 'next/cache';
import AdminLayout from '../../components/layout/AdminLayout';
import { hrefForMenu } from '../../components/layout/AdminSidebar';
import { InstantOrdersPanel } from '../../components/orders/InstantOrders';
import { ScheduledOrdersPanel } from '../../components/orders/ScheduledOrders';
import { useAuth } from '../../context/AuthContext';
import { onAdminChange, useRealtimeConnected } from '../../lib/realtime';
import { apiRequest, ApiError } from '../../lib/api';
import { rupiah } from '../../lib/wallet';
import { formatDate as formatWibDate, formatDateTime, todayWib } from '../../lib/date';
import { useLabels } from '../../lib/labels';
import { DashboardOverview as Overview, SalesReport, SalesSummary } from '../../types';
import {
  AlertCircle,
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  CalendarDays,
  Clock,
  Loader2,
  Package,
  RefreshCw,
  ShoppingBag,
  TrendingUp,
  Wallet,
} from 'lucide-react';

const PRESETS: { label: string; from: () => string; to: () => string }[] = [
  { label: 'Hari ini', from: () => todayWib(), to: () => todayWib() },
  { label: 'Kemarin', from: () => todayWib(-1), to: () => todayWib(-1) },
  { label: '7 hari', from: () => todayWib(-6), to: () => todayWib() },
  { label: 'Bulan ini', from: () => todayWib().slice(0, 8) + '01', to: () => todayWib() },
  { label: '30 hari', from: () => todayWib(-29), to: () => todayWib() },
];

const compact = new Intl.NumberFormat('id-ID', { notation: 'compact', maximumFractionDigits: 1 });

/** rupiah() drops the sign; a loss must still read as negative. */
const signedRupiah = (n: number) => (n < 0 ? '−' : '') + rupiah(n);

const formatDate = (ymd: string, long = false) => formatWibDate(ymd, long ? 'full' : 'short');

const formatRange = (from: string, to: string, long = false) =>
  from === to ? formatDate(from, long) : `${formatDate(from)} – ${formatDate(to)}`;

const formatTime = (iso: string) => formatDateTime(iso, { year: false });

/** Percentage change, or null when there is nothing to compare against. */
const change = (current: number, previous: number): number | null =>
  previous === 0 ? (current === 0 ? 0 : null) : ((current - previous) / Math.abs(previous)) * 100;

// "Today" is read during render, so keep it out of the prerendered shell.
export default function DashboardOverviewPage() {
  return (
    <Suspense>
      <DashboardOverview />
    </Suspense>
  );
}

function DashboardOverview() {
  use(io());
  const { get } = useLabels();
  const { canView } = useAuth();
  const [report, setReport] = useState<SalesReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dateFrom, setDateFrom] = useState(todayWib());
  const [dateTo, setDateTo] = useState(todayWib());
  const [metric, setMetric] = useState<'revenue' | 'orders'>('revenue');
  const [overview, setOverview] = useState<Overview | null>(null);

  // Section cards are "now / today / this month", independent of the sales report's date range.
  const loadOverview = useCallback(() => {
    apiRequest<Overview>('/admin/dashboard/overview')
      .then(setOverview)
      .catch(() => setOverview({ sections: [] }));
  }, []);

  // Refresh the cards every minute so counts like Pesanan Instant stay current.
  useEffect(() => {
    loadOverview();
    const t = setInterval(loadOverview, 60_000);
    return () => clearInterval(t);
  }, [loadOverview]);

  const load = useCallback(async () => {
    if (!dateFrom || !dateTo) return;
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ date_from: dateFrom, date_to: dateTo });
      setReport(await apiRequest<SalesReport>(`/admin/sales-report?${params}`));
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message : 'Gagal memuat laporan penjualan.');
    } finally {
      setLoading(false);
    }
  }, [dateFrom, dateTo]);

  useEffect(() => {
    const t = setTimeout(load, 200);
    return () => clearTimeout(t);
  }, [load]);

  // Realtime: the backend signals over Reverb whenever dashboard data changes; refetch both parts.
  const loadRef = useRef(load);
  useEffect(() => {
    loadRef.current = load;
  }, [load]);
  useEffect(
    () =>
      onAdminChange('admin.dashboard', () => {
        loadOverview();
        void loadRef.current();
      }),
    [loadOverview],
  );
  const live = useRealtimeConnected();

  const cur = report?.period.summary;
  const prev = report?.previous.summary;
  const isToday = dateFrom === todayWib() && dateTo === todayWib();
  const compareLabel = !report
    ? ''
    : isToday
      ? 'kemarin'
      : report.period.days === 1 && dateFrom === todayWib(-1)
        ? 'kemarin lusa'
        : formatRange(report.previous.date_from, report.previous.date_to);

  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  const kpis: { label: string; key: keyof SalesSummary; money?: boolean; icon: React.ElementType; tone: string }[] = [
    { label: 'Total penjualan', key: 'revenue', money: true, icon: Wallet, tone: 'bg-emerald-50 text-emerald-600 ring-emerald-100' },
    { label: 'Total keuntungan', key: 'gross_profit', money: true, icon: TrendingUp, tone: 'bg-teal-50 text-teal-600 ring-teal-100' },
    { label: 'Pesanan', key: 'orders', icon: ShoppingBag, tone: 'bg-blue-50 text-blue-600 ring-blue-100' },
    { label: 'Produk terjual', key: 'items_sold', icon: Package, tone: 'bg-purple-50 text-purple-600 ring-purple-100' },
  ];

  const secondary: { label: string; key: keyof SalesSummary; money?: boolean; hint?: string }[] = [
    { label: 'Penjualan produk', key: 'product_sales', money: true, hint: 'Setelah diskon, tanpa ongkir' },
    { label: 'Total modal', key: 'cost', money: true },
    { label: 'Rata-rata per pesanan', key: 'average_order', money: true },
    { label: 'Penjualan sudah dibayar', key: 'revenue_paid', money: true },
    { label: 'Pembeli', key: 'buyers' },
    { label: 'Pelanggan baru', key: 'new_customers' },
    { label: 'Pesanan selesai', key: 'completed' },
    { label: 'Dibatalkan', key: 'cancelled', hint: 'Tidak dihitung ke penjualan' },
  ];

  const fmt = (v: number, money?: boolean) => (money ? signedRupiah(v) : v.toLocaleString('id-ID'));


  return (
    <AdminLayout>
      <div className="space-y-8">
        <div>
          <h1 className="flex items-center gap-3 text-2xl font-bold text-slate-900">
            Ringkasan Dashboard
            <span
              title={live ? 'Terhubung: data diperbarui otomatis saat ada perubahan' : 'Koneksi realtime terputus: data diperbarui berkala'}
              className={`inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                live ? 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200' : 'bg-slate-100 text-slate-500'
              }`}
            >
              <span className={`h-1.5 w-1.5 rounded-full ${live ? 'animate-pulse bg-emerald-500' : 'bg-slate-400'}`} />
              {live ? 'Realtime' : 'Offline'}
            </span>
          </h1>
          <p className="mt-1 text-sm text-slate-500">Ringkasan per bagian menu. Hanya menu yang boleh Anda akses yang ditampilkan.</p>
        </div>

        <div className="space-y-4">
          {canView('orders') && (
            <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-2">
              <InstantOrdersPanel />
              <ScheduledOrdersPanel />
            </div>
          )}

          <div className="space-y-6">
            {/* Header & date filter */}
            <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <h2 className="text-lg font-bold text-slate-900">Laporan Penjualan</h2>
                <p className="mt-1 flex items-center gap-1.5 text-sm text-slate-500">
                  <CalendarDays className="h-4 w-4" />
                  {formatRange(dateFrom, dateTo, true)}
                  {compareLabel && <span className="text-slate-400">· dibanding {compareLabel}</span>}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                {PRESETS.map((pr) => {
                  const active = dateFrom === pr.from() && dateTo === pr.to();
                  return (
                    <button
                      key={pr.label}
                      type="button"
                      onClick={() => {
                        setDateFrom(pr.from());
                        setDateTo(pr.to());
                      }}
                      className={`rounded-full border px-3 py-1 text-xs font-medium ${active ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'}`}
                    >
                      {pr.label}
                    </button>
                  );
                })}
                <input
                  type="date"
                  className={input}
                  value={dateFrom}
                  max={todayWib()}
                  onChange={(e) => {
                    setDateFrom(e.target.value);
                    if (e.target.value > dateTo) setDateTo(e.target.value);
                  }}
                  aria-label="Dari tanggal"
                />
                <span className="text-sm text-slate-400">s/d</span>
                <input
                  type="date"
                  className={input}
                  value={dateTo}
                  min={dateFrom}
                  max={todayWib()}
                  onChange={(e) => setDateTo(e.target.value)}
                  aria-label="Sampai tanggal"
                />
                <button
                  type="button"
                  onClick={() => {
                    load();
                    loadOverview();
                  }}
                  className="rounded-lg border border-slate-200 bg-white p-2 text-slate-500 hover:text-emerald-600"
                  title="Muat ulang"
                >
                  <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
                </button>
              </div>
            </div>

            {error && (
              <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
                <AlertCircle className="h-4 w-4" /> {error}
              </div>
            )}

            {/* Main KPIs */}
            <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {kpis.map((k) => {
                const Icon = k.icon;
                const value = cur?.[k.key] ?? 0;
                const before = prev?.[k.key] ?? 0;
                return (
                  <div key={k.key} className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs">
                    <div className="flex items-start justify-between">
                      <div className="min-w-0">
                        <p className="text-xs font-semibold text-slate-500">{k.label}</p>
                        {!report ? (
                          <div className="skeleton mt-3 h-8 w-28" />
                        ) : (
                          <p className="mt-2 truncate text-2xl font-extrabold tracking-tight text-slate-900 tabular-nums">
                            {fmt(value, k.money)}
                          </p>
                        )}
                      </div>
                      <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ring-1 ${k.tone}`}>
                        <Icon className="h-5 w-5" />
                      </div>
                    </div>
                    {report && (
                      <div className="mt-3 flex flex-wrap items-center gap-2 text-xs">
                        <Delta pct={change(value, before)} />
                        <span className="text-slate-400">
                          {compareLabel}: {fmt(before, k.money)}
                        </span>
                        {k.key === 'gross_profit' && cur && (
                          <span className="text-slate-500">· margin {cur.margin.toLocaleString('id-ID')}%</span>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </section>

            {/* Secondary numbers */}
            {cur && cur.items_without_cost > 0 && (
              <div className="flex flex-wrap items-center gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
                <AlertCircle className="h-4 w-4 shrink-0" />
                {cur.items_without_cost.toLocaleString('id-ID')} produk terjual belum punya harga modal, sehingga keuntungan terlihat lebih
                besar dari seharusnya.
                <Link href="/dashboard/products" className="font-semibold underline">
                  Lengkapi harga modal
                </Link>
              </div>
            )}

            <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
              {secondary.map((s) => (
                <div key={s.key} className="rounded-xl border border-slate-200/80 bg-white px-4 py-3 shadow-xs">
                  <p className="text-[11px] font-semibold text-slate-500">{s.label}</p>
                  <p className="mt-1 text-base font-bold text-slate-900 tabular-nums">{cur ? fmt(cur[s.key], s.money) : '—'}</p>
                  <p className="mt-0.5 text-[11px] text-slate-400">
                    {s.hint ?? (prev ? `${compareLabel}: ${fmt(prev[s.key], s.money)}` : '')}
                  </p>
                </div>
              ))}
            </section>

            {/* Overall */}
            {/* Pesanan perlu diproses / menunggu pembayaran are section cards (menu Pesanan) above. */}
            <section className="grid grid-cols-2 gap-3 xl:grid-cols-4">
              <OverallCard label="Total penjualan keseluruhan" value={report ? rupiah(report.overall.revenue_total) : '—'} hint={report ? `${report.overall.orders_total.toLocaleString('id-ID')} pesanan` : ''} />
              <OverallCard label="Total keuntungan keseluruhan" value={report ? signedRupiah(report.overall.profit_total) : '—'} hint="Penjualan produk − diskon − modal" />
              <OverallCard label="Penjualan bulan ini" value={report ? rupiah(report.overall.revenue_this_month) : '—'} hint={report ? `${report.overall.orders_this_month.toLocaleString('id-ID')} pesanan` : ''} />
              <OverallCard label="Keuntungan bulan ini" value={report ? signedRupiah(report.overall.profit_this_month) : '—'} hint="Sejak tanggal 1 bulan ini" />
            </section>

            <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
              {/* Status breakdown */}
              <Panel title="Status pesanan" subtitle="Pesanan yang dibuat pada periode ini">
                {!report ? (
                  <PanelSkeleton />
                ) : (
                  <div className="space-y-3">
                    {report.by_status.map((s) => {
                      const total = report.by_status.reduce((a, b) => a + b.orders, 0);
                      const label = get('order_status', s.status);
                      return (
                        <div key={s.status}>
                          <div className="mb-1 flex items-center justify-between text-xs">
                            <span className={`rounded-md px-2 py-0.5 font-semibold ${label.badge}`}>{label.label}</span>
                            <span className="text-slate-500">
                              <b className="text-slate-800">{s.orders}</b> · {rupiah(s.revenue)}
                            </span>
                          </div>
                          <div className="h-1.5 overflow-hidden rounded-full bg-slate-100">
                            <div className="h-full rounded-full bg-emerald-500" style={{ width: `${total ? (s.orders / total) * 100 : 0}%` }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </Panel>

              {/* Payment methods */}
              <Panel title="Metode pembayaran" subtitle="Penjualan per metode (tanpa pesanan batal)">
                {!report ? (
                  <PanelSkeleton />
                ) : report.by_payment_method.length === 0 ? (
                  <Empty />
                ) : (
                  <div className="space-y-3">
                    {report.by_payment_method.map((m) => (
                      <div key={m.method}>
                        <div className="mb-1 flex items-center justify-between text-xs">
                          <span className="font-semibold text-slate-700">{m.method}</span>
                          <span className="text-slate-500">
                            {m.orders} pesanan · <b className="text-slate-800">{rupiah(m.revenue)}</b>
                          </span>
                        </div>
                        <div className="h-1.5 overflow-hidden rounded-full bg-slate-100">
                          <div
                            className="h-full rounded-full bg-blue-500"
                            style={{ width: `${cur?.revenue ? (m.revenue / cur.revenue) * 100 : 0}%` }}
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </Panel>

              {/* Top products */}
              <Panel title="Produk terlaris" subtitle="Berdasarkan jumlah terjual pada periode ini" href="/dashboard/products">
                {!report ? (
                  <PanelSkeleton />
                ) : report.top_products.length === 0 ? (
                  <Empty />
                ) : (
                  <ol className="divide-y divide-slate-100">
                    {report.top_products.map((p, i) => (
                      <li key={`${p.product_id}-${p.name}`} className="flex items-center gap-3 py-2.5">
                        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-emerald-50 text-xs font-bold text-emerald-700">
                          {i + 1}
                        </span>
                        <span className="min-w-0 flex-1 truncate text-sm font-medium text-slate-800">{p.name}</span>
                        <span className="shrink-0 text-right text-xs text-slate-500">
                          <b className="block text-sm text-slate-900">{p.sold.toLocaleString('id-ID')} terjual</b>
                          {rupiah(p.revenue)}
                          <span className={`block ${p.profit === null ? 'text-slate-400' : p.profit < 0 ? 'text-rose-600' : 'text-teal-600'}`}>
                            {p.profit === null ? 'Modal belum diisi' : `Untung ${p.profit < 0 ? '−' : ''}${rupiah(p.profit)}`}
                          </span>
                        </span>
                      </li>
                    ))}
                  </ol>
                )}
              </Panel>

              {/* Recent orders */}
              <Panel title="Pesanan terbaru" subtitle="Pesanan terakhir pada periode ini" href="/dashboard/orders">
                {!report ? (
                  <PanelSkeleton />
                ) : report.recent_orders.length === 0 ? (
                  <Empty />
                ) : (
                  <ul className="divide-y divide-slate-100">
                    {report.recent_orders.map((o) => {
                      const label = get('order_status', o.status);
                      return (
                        <li key={o.id} className="flex items-center justify-between gap-3 py-2.5">
                          <div className="min-w-0">
                            <p className="truncate text-sm font-semibold text-slate-900">{o.order_number}</p>
                            <p className="flex items-center gap-1 truncate text-xs text-slate-500">
                              <Clock className="h-3 w-3" />
                              {formatTime(o.created_at)} · {o.customer ?? '-'}
                            </p>
                          </div>
                          <div className="shrink-0 text-right">
                            <p className="text-sm font-bold text-slate-900">{rupiah(o.grand_total)}</p>
                            <span className={`rounded-md px-2 py-0.5 text-[10px] font-semibold ${label.badge}`}>{label.label}</span>
                          </div>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </Panel>
            </div>

            {/* Chart */}
            <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
              <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-6 py-4">
                <div>
                  <h3 className="text-base font-bold text-slate-900">
                    {metric === 'revenue' ? 'Penjualan' : 'Jumlah pesanan'} per {report?.granularity === 'hour' ? 'jam' : 'hari'}
                  </h3>
                  <div className="mt-1 flex items-center gap-4 text-xs text-slate-500">
                    <span className="flex items-center gap-1.5">
                      <span className="h-2.5 w-2.5 rounded-sm bg-emerald-500" /> Periode dipilih
                    </span>
                    <span className="flex items-center gap-1.5">
                      <span className="h-2.5 w-2.5 rounded-sm bg-slate-300" /> {compareLabel || 'Sebelumnya'}
                    </span>
                  </div>
                </div>
                <div className="flex rounded-lg border border-slate-200 p-0.5 text-xs font-semibold">
                  {(['revenue', 'orders'] as const).map((m) => (
                    <button
                      key={m}
                      type="button"
                      onClick={() => setMetric(m)}
                      className={`rounded-md px-3 py-1.5 ${metric === m ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
                    >
                      {m === 'revenue' ? 'Penjualan' : 'Pesanan'}
                    </button>
                  ))}
                </div>
              </div>
              <div className="p-5">
                {!report ? (
                  <div className="skeleton h-64" />
                ) : (
                  <SalesChart report={report} metric={metric} compareLabel={compareLabel} />
                )}
              </div>
            </section>

            {loading && report && (
              <div className="fixed bottom-4 right-4 flex items-center gap-2 rounded-full bg-slate-900 px-3 py-1.5 text-xs text-white shadow-lg">
                <Loader2 className="h-3.5 w-3.5 animate-spin" /> Memuat…
              </div>
            )}
          </div>
        </div>

        {overview?.sections
          .map((s) => (
            <DashboardSection key={s.title} title={s.title}>
              <SectionCards cards={s.cards} loading={false} />
            </DashboardSection>
          ))}
      </div>
    </AdminLayout>
  );
}

/** A sidebar section (Utama, Operasional, ...) with the same small caps heading as the menu. */
function DashboardSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-4">
      <div className="flex items-center gap-3">
        <h2 className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">{title}</h2>
        <div className="h-px flex-1 bg-slate-200" />
      </div>
      {children}
    </section>
  );
}

function SectionCards({ cards, loading }: { cards: Overview['sections'][number]['cards']; loading: boolean }) {
  if (loading) {
    return (
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="skeleton h-[88px] rounded-2xl" />
        ))}
      </div>
    );
  }
  if (cards.length === 0) return null;

  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4">
      {cards.map((c) => (
        <OverallCard
          key={`${c.menu}-${c.label}`}
          label={c.label}
          value={c.money ? signedRupiah(c.value) : c.value.toLocaleString('id-ID')}
          hint={c.hint ?? ''}
          href={hrefForMenu(c.menu) ?? undefined}
          alert={c.alert}
        />
      ))}
    </div>
  );
}

function Delta({ pct }: { pct: number | null }) {
  if (pct === null) {
    return <span className="rounded-md bg-emerald-50 px-1.5 py-0.5 font-semibold text-emerald-700">Baru</span>;
  }
  const up = pct > 0;
  const flat = Math.abs(pct) < 0.05;
  const Icon = up ? ArrowUpRight : ArrowDownRight;
  return (
    <span
      className={`inline-flex items-center gap-0.5 rounded-md px-1.5 py-0.5 font-semibold ${
        flat ? 'bg-slate-100 text-slate-600' : up ? 'bg-emerald-50 text-emerald-700' : 'bg-rose-50 text-rose-700'
      }`}
    >
      {!flat && <Icon className="h-3 w-3" />}
      {flat ? '0%' : `${Math.abs(pct).toLocaleString('id-ID', { maximumFractionDigits: 1 })}%`}
    </span>
  );
}

function SalesChart({ report, metric, compareLabel }: { report: SalesReport; metric: 'revenue' | 'orders'; compareLabel: string }) {
  const [hover, setHover] = useState<number | null>(null);
  const rows = report.series;
  const value = (r: SalesReport['series'][number]) => (metric === 'revenue' ? r.revenue : r.orders);
  const previous = (r: SalesReport['series'][number]) => (metric === 'revenue' ? r.previous_revenue : r.previous_orders);
  const max = Math.max(1, ...rows.map((r) => Math.max(value(r), previous(r))));
  const fmt = (v: number) => (metric === 'revenue' ? rupiah(v) : `${v.toLocaleString('id-ID')} pesanan`);
  const labelEvery = Math.ceil(rows.length / 12);
  const axisLabel = (label: string) => (report.granularity === 'hour' ? label.slice(0, 2) : formatDate(label).replace(/ \d{4}$/, ''));
  const active = hover !== null ? rows[hover] : null;

  return (
    <div>
      <div className="mb-3 h-10 text-xs">
        {active ? (
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
            <span className="font-semibold text-slate-700">
              {report.granularity === 'hour' ? `Jam ${active.label}` : formatDate(active.label, true)}
            </span>
            <span className="text-emerald-700">
              Periode dipilih: <b>{fmt(value(active))}</b>
            </span>
            <span className="text-slate-500">
              {compareLabel}: <b>{fmt(previous(active))}</b>
            </span>
          </div>
        ) : (
          <span className="text-slate-400">Arahkan kursor ke grafik untuk melihat detail.</span>
        )}
      </div>
      <div className="flex">
        <div className="flex h-56 w-14 shrink-0 flex-col justify-between pr-2 text-right text-[10px] text-slate-400">
          <span>{metric === 'revenue' ? compact.format(max) : max}</span>
          <span>{metric === 'revenue' ? compact.format(max / 2) : Math.round(max / 2)}</span>
          <span>0</span>
        </div>
        <div className="min-w-0 flex-1">
          <div className="relative flex h-56 items-end gap-px border-b border-l border-slate-200" onMouseLeave={() => setHover(null)}>
            <div className="pointer-events-none absolute inset-x-0 top-0 border-t border-dashed border-slate-100" />
            <div className="pointer-events-none absolute inset-x-0 top-1/2 border-t border-dashed border-slate-100" />
            {rows.map((r, i) => (
              <div
                key={r.label}
                onMouseEnter={() => setHover(i)}
                className={`relative flex h-full flex-1 items-end justify-center gap-px rounded-t px-px ${hover === i ? 'bg-slate-50' : ''}`}
              >
                <div className="w-1/2 max-w-3 rounded-t bg-slate-300" style={{ height: `${(previous(r) / max) * 100}%` }} />
                <div className="w-1/2 max-w-3 rounded-t bg-emerald-500" style={{ height: `${(value(r) / max) * 100}%` }} />
              </div>
            ))}
          </div>
          <div className="flex gap-px pt-1.5 text-[10px] text-slate-400">
            {rows.map((r, i) => (
              <span key={r.label} className="flex-1 truncate text-center">
                {i % labelEvery === 0 ? axisLabel(r.label) : ''}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function OverallCard({ label, value, hint, href, alert }: { label: string; value: string; hint: string; href?: string; alert?: boolean }) {
  const body = (
    <>
      <p className="text-xs font-semibold text-slate-500">{label}</p>
      <p className={`mt-1 truncate text-xl font-extrabold tabular-nums ${alert ? 'text-amber-600' : 'text-slate-900'}`}>{value}</p>
      <p className="mt-1 flex items-center justify-between text-[11px] text-slate-400">
        {hint}
        {href && <ArrowRight className="h-3.5 w-3.5" />}
      </p>
    </>
  );
  const cls = 'rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs';
  return href ? (
    <Link href={href} className={`${cls} transition-colors hover:border-emerald-300`}>
      {body}
    </Link>
  ) : (
    <div className={cls}>{body}</div>
  );
}

function Panel({ title, subtitle, href, children }: { title: string; subtitle: string; href?: string; children: React.ReactNode }) {
  return (
    <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
      <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4">
        <div>
          <h3 className="text-base font-bold text-slate-900">{title}</h3>
          <p className="text-xs text-slate-500">{subtitle}</p>
        </div>
        {href && (
          <Link href={href} className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-700">
            Semua <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        )}
      </div>
      <div className="px-6 py-4">{children}</div>
    </section>
  );
}

function PanelSkeleton() {
  return (
    <div className="space-y-3">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="skeleton h-8" />
      ))}
    </div>
  );
}

function Empty() {
  return <p className="py-8 text-center text-sm text-slate-400">Belum ada data pada periode ini.</p>;
}
