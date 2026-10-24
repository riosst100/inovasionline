'use client';

import React, { Suspense, use, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { io } from 'next/cache';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequestFull, ApiError } from '../../../lib/api';
import { formatDateTime, rupiah, todayWib, TRANSACTION_TYPE_LABEL } from '../../../lib/wallet';
import { PaginationMeta, WalletReport, WalletTransactionRow } from '../../../types';
import {
  AlertCircle,
  ArrowDownLeft,
  ArrowUpRight,
  ChevronLeft,
  ChevronRight,
  FileBarChart,
  Loader2,
  Search,
  Users2,
} from 'lucide-react';

type Direction = '' | 'in' | 'out';

const PRESETS: { label: string; from: () => string; to: () => string }[] = [
  { label: 'Hari ini', from: () => todayWib(), to: () => todayWib() },
  { label: '7 hari', from: () => todayWib(-6), to: () => todayWib() },
  { label: 'Bulan ini', from: () => todayWib().slice(0, 8) + '01', to: () => todayWib() },
  { label: '30 hari', from: () => todayWib(-29), to: () => todayWib() },
  { label: 'Semua', from: () => '', to: () => '' },
];

// The date presets read "today" during render, so keep it out of the prerendered shell.
export default function WalletReportPage() {
  return (
    <Suspense>
      <WalletReportContent />
    </Suspense>
  );
}

function WalletReportContent() {
  use(io());
  const [report, setReport] = useState<WalletReport | null>(null);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dateFrom, setDateFrom] = useState(PRESETS[2].from());
  const [dateTo, setDateTo] = useState(PRESETS[2].to());
  const [direction, setDirection] = useState<Direction>('');
  const [type, setType] = useState<WalletTransactionRow['type'] | ''>('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ per_page: '25', page: String(page) });
      if (dateFrom) params.set('date_from', dateFrom);
      if (dateTo) params.set('date_to', dateTo);
      if (direction) params.set('direction', direction);
      if (type) params.set('type', type);
      if (search.trim()) params.set('search', search.trim());
      const res = await apiRequestFull<WalletReport>(`/admin/wallet-report?${params}`);
      setReport(res.data);
      setMeta(res.meta ?? null);
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message : 'Gagal memuat laporan saldo.');
    } finally {
      setLoading(false);
    }
  }, [dateFrom, dateTo, direction, type, search, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const filter = (next: () => void) => {
    next();
    setPage(1);
  };

  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';
  const p = report?.period;
  const periodLabel = dateFrom || dateTo ? `${dateFrom || 'awal'} s/d ${dateTo || 'hari ini'}` : 'Semua waktu';

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <FileBarChart className="h-6 w-6 text-emerald-600" />
            <h1 className="text-2xl font-bold text-slate-900">Laporan Saldo Belanja</h1>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Total saldo belanja yang dipegang untuk seluruh customer, beserta rincian pemasukan dan pengeluarannya.
          </p>
        </div>

        <div className="grid gap-3 lg:grid-cols-3">
          <div className="rounded-2xl bg-gradient-to-br from-teal-600 to-sky-600 p-5 text-white lg:col-span-1">
            <p className="text-xs opacity-80">Total saldo belanja semua customer (saat ini)</p>
            <p className="mt-1 text-3xl font-extrabold">{report ? rupiah(report.total_balance) : '—'}</p>
            <p className="mt-2 flex items-center gap-1.5 text-xs opacity-90">
              <Users2 className="h-3.5 w-3.5" />
              {report ? `${report.customers_with_balance.toLocaleString('id-ID')} customer memiliki saldo` : ''}
            </p>
          </div>
          <div className="grid grid-cols-2 gap-3 lg:col-span-2 lg:grid-cols-4">
            <Stat label="Saldo awal periode" value={p ? rupiah(p.opening_balance) : '—'} />
            <Stat label="Pemasukan" value={p ? '+' + rupiah(p.total_in) : '—'} tone="in" />
            <Stat label="Pengeluaran" value={p ? '−' + rupiah(p.total_out) : '—'} tone="out" />
            <Stat label="Saldo akhir periode" value={p ? rupiah(p.closing_balance) : '—'} hint={p ? `Net ${p.net >= 0 ? '+' : '−'}${rupiah(p.net)}` : ''} />
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {PRESETS.map((pr) => {
            const active = dateFrom === pr.from() && dateTo === pr.to();
            return (
              <button
                key={pr.label}
                type="button"
                onClick={() =>
                  filter(() => {
                    setDateFrom(pr.from());
                    setDateTo(pr.to());
                  })
                }
                className={`rounded-full border px-3 py-1 text-xs font-medium ${active ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-600 hover:bg-slate-50'}`}
              >
                {pr.label}
              </button>
            );
          })}
          <input type="date" className={input} value={dateFrom} onChange={(e) => filter(() => setDateFrom(e.target.value))} aria-label="Dari tanggal" />
          <span className="text-sm text-slate-400">s/d</span>
          <input type="date" className={input} value={dateTo} onChange={(e) => filter(() => setDateTo(e.target.value))} aria-label="Sampai tanggal" />
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        <div className="grid gap-4 lg:grid-cols-2">
          <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="mb-3 flex items-center justify-between">
              <p className="flex items-center gap-2 font-semibold text-slate-800">
                <ArrowDownLeft className="h-4 w-4 text-emerald-600" /> Pemasukan
              </p>
              <span className="text-xs text-slate-400">{periodLabel}</span>
            </div>
            <Breakdown rows={report?.income_by_type.map((r) => ({ label: TRANSACTION_TYPE_LABEL[r.type] ?? r.type, total: r.total })) ?? []} total={p?.total_in ?? 0} tone="in" />

            <p className="mb-2 mt-5 text-xs font-semibold uppercase tracking-wide text-slate-500">Top up per metode pembayaran</p>
            {report && report.income_by_method.length === 0 ? (
              <p className="text-sm text-slate-400">Belum ada top up berhasil.</p>
            ) : (
              <div className="divide-y divide-slate-100 rounded-xl border border-slate-100">
                {report?.income_by_method.map((m) => (
                  <div key={m.method} className="flex items-center justify-between px-3 py-2 text-sm">
                    <span className="text-slate-700">
                      {m.method} <span className="text-xs text-slate-400">· {m.count}x</span>
                    </span>
                    <span className="font-semibold text-emerald-700">+{rupiah(m.total)}</span>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="mb-3 flex items-center justify-between">
              <p className="flex items-center gap-2 font-semibold text-slate-800">
                <ArrowUpRight className="h-4 w-4 text-rose-600" /> Pengeluaran
              </p>
              <span className="text-xs text-slate-400">{periodLabel}</span>
            </div>
            <Breakdown rows={report?.expense_by_type.map((r) => ({ label: TRANSACTION_TYPE_LABEL[r.type] ?? r.type, total: r.total })) ?? []} total={p?.total_out ?? 0} tone="out" />
          </section>
        </div>

        <section className="space-y-3">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex rounded-lg border border-slate-200 bg-white p-0.5 text-sm">
              {([['', 'Semua'], ['in', 'Pemasukan'], ['out', 'Pengeluaran']] as [Direction, string][]).map(([d, label]) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => filter(() => setDirection(d))}
                  className={`rounded-md px-3 py-1.5 font-medium ${direction === d ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
                >
                  {label}
                </button>
              ))}
            </div>
            <select className={input} value={type} onChange={(e) => filter(() => setType(e.target.value as WalletTransactionRow['type'] | ''))}>
              <option value="">Semua jenis</option>
              {Object.entries(TRANSACTION_TYPE_LABEL).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
            <div className="relative min-w-[220px] flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                className={`${input} w-full pl-9`}
                placeholder="Cari customer"
                value={search}
                onChange={(e) => filter(() => setSearch(e.target.value))}
              />
            </div>
          </div>

          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            {loading && !report ? (
              <div className="flex justify-center p-10">
                <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
              </div>
            ) : !report || report.transactions.length === 0 ? (
              <p className="p-10 text-center text-sm text-slate-400">Tidak ada transaksi pada periode ini.</p>
            ) : (
              <table className={`w-full text-sm ${loading ? 'opacity-60' : ''}`}>
                <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Waktu</th>
                    <th className="px-4 py-3">Customer</th>
                    <th className="px-4 py-3">Jenis</th>
                    <th className="px-4 py-3">Keterangan</th>
                    <th className="px-4 py-3 text-right">Nominal</th>
                    <th className="px-4 py-3 text-right">Saldo</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {report.transactions.map((t) => (
                    <tr key={t.id} className="align-top">
                      <td className="whitespace-nowrap px-4 py-3 text-slate-500">{formatDateTime(t.created_at)}</td>
                      <td className="px-4 py-3">
                        {t.user ? (
                          <Link href={`/dashboard/customers/${t.user.id}`} className="font-medium text-slate-800 hover:text-emerald-700">
                            {t.user.name}
                          </Link>
                        ) : (
                          '—'
                        )}
                        <p className="text-xs text-slate-500">{t.user?.email || t.user?.phone}</p>
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold ${t.amount >= 0 ? 'bg-emerald-50 text-emerald-700' : 'bg-rose-50 text-rose-700'}`}
                        >
                          {TRANSACTION_TYPE_LABEL[t.type] ?? t.type}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        <p>{t.description}</p>
                        {t.payment_method && <p className="text-xs font-medium text-slate-700">Metode: {t.payment_method}</p>}
                        <p className="text-xs text-slate-400">
                          {[t.topup?.topup_number, t.order?.order_number, t.admin && `oleh ${t.admin.name}`].filter(Boolean).join(' · ')}
                        </p>
                      </td>
                      <td className={`whitespace-nowrap px-4 py-3 text-right font-semibold ${t.amount >= 0 ? 'text-emerald-600' : 'text-rose-600'}`}>
                        {t.amount >= 0 ? '+' : '−'}
                        {rupiah(t.amount)}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-right text-slate-500">{rupiah(t.balance_after)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {meta && meta.last_page > 1 && (
            <div className="flex items-center justify-between text-xs text-slate-500">
              <span>
                Halaman {meta.current_page} dari {meta.last_page} · {meta.total} transaksi
              </span>
              <div className="flex gap-1">
                <button
                  disabled={page <= 1}
                  onClick={() => setPage(page - 1)}
                  className="rounded-lg border border-slate-200 p-1.5 hover:bg-slate-50 disabled:opacity-40"
                  aria-label="Sebelumnya"
                >
                  <ChevronLeft className="h-4 w-4" />
                </button>
                <button
                  disabled={page >= meta.last_page}
                  onClick={() => setPage(page + 1)}
                  className="rounded-lg border border-slate-200 p-1.5 hover:bg-slate-50 disabled:opacity-40"
                  aria-label="Berikutnya"
                >
                  <ChevronRight className="h-4 w-4" />
                </button>
              </div>
            </div>
          )}
        </section>
      </div>
    </AdminLayout>
  );
}

function Stat({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: 'in' | 'out' }) {
  const color = tone === 'in' ? 'text-emerald-700' : tone === 'out' ? 'text-rose-700' : 'text-slate-900';
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-xs text-slate-500">{label}</p>
      <p className={`mt-1 text-lg font-bold ${color}`}>{value}</p>
      {hint && <p className="text-xs text-slate-400">{hint}</p>}
    </div>
  );
}

function Breakdown({ rows, total, tone }: { rows: { label: string; total: number }[]; total: number; tone: 'in' | 'out' }) {
  if (rows.length === 0) return <p className="text-sm text-slate-400">Tidak ada data.</p>;
  const bar = tone === 'in' ? 'bg-emerald-500' : 'bg-rose-500';
  return (
    <div className="space-y-2.5">
      {rows
        .slice()
        .sort((a, b) => b.total - a.total)
        .map((r) => (
          <div key={r.label}>
            <div className="flex items-center justify-between text-sm">
              <span className="text-slate-700">{r.label}</span>
              <span className="font-semibold text-slate-900">{rupiah(r.total)}</span>
            </div>
            <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-slate-100">
              <div className={`h-full rounded-full ${bar}`} style={{ width: `${total > 0 ? (r.total / total) * 100 : 0}%` }} />
            </div>
          </div>
        ))}
    </div>
  );
}
