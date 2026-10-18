'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest, apiRequestFull, ApiError } from '../../../lib/api';
import { formatDateTime, rupiah, TOPUP_STATUS } from '../../../lib/wallet';
import { PaginationMeta, WalletTopupDetail, WalletTopupRow, WalletTopupStatus, WalletTopupSummary } from '../../../types';
import {
  AlertCircle,
  ArrowUpCircle,
  Check,
  ChevronLeft,
  ChevronRight,
  Copy,
  ExternalLink,
  Loader2,
  RefreshCw,
  Search,
  X,
} from 'lucide-react';

const STATUSES: WalletTopupStatus[] = ['pending', 'paid', 'failed', 'expired'];

function StatusBadge({ status }: { status: WalletTopupStatus }) {
  const s = TOPUP_STATUS[status];
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ${s.badge}`}>
      {status === 'pending' && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-amber-500" />}
      {s.label}
    </span>
  );
}

export default function WalletTopupsPage() {
  const [rows, setRows] = useState<WalletTopupRow[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [summary, setSummary] = useState<WalletTopupSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<WalletTopupStatus | ''>('');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ per_page: '25', page: String(page) });
      if (status) params.set('status', status);
      if (search.trim()) params.set('search', search.trim());
      if (dateFrom) params.set('date_from', dateFrom);
      if (dateTo) params.set('date_to', dateTo);
      const res = await apiRequestFull<WalletTopupRow[]>(`/admin/wallet-topups?${params}`);
      setRows(res.data ?? []);
      setMeta(res.meta ?? null);
      setSummary(((res.meta as unknown as { summary?: WalletTopupSummary }) ?? {}).summary ?? null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat riwayat top up.');
    } finally {
      setLoading(false);
    }
  }, [status, search, dateFrom, dateTo, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const filter = (next: () => void) => {
    next();
    setPage(1);
  };

  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';
  const running = summary?.pending.count ?? 0;

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <ArrowUpCircle className="h-6 w-6 text-emerald-600" />
            <h1 className="text-2xl font-bold text-slate-900">Top Up History</h1>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Semua top up saldo belanja customer via Midtrans, termasuk yang masih berjalan (menunggu pembayaran).
          </p>
        </div>

        {running > 0 && status !== 'pending' && (
          <button
            type="button"
            onClick={() => filter(() => setStatus('pending'))}
            className="flex w-full items-center justify-between gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-left text-sm text-amber-800 hover:bg-amber-100"
          >
            <span className="flex items-center gap-2">
              <span className="h-2 w-2 animate-pulse rounded-full bg-amber-500" />
              <b>{running}</b> transaksi top up sedang berjalan · total {rupiah(summary?.pending.total ?? 0)}
            </span>
            <span className="font-semibold">Lihat →</span>
          </button>
        )}

        <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
          <button
            type="button"
            onClick={() => filter(() => setStatus(''))}
            className={`rounded-xl border p-3 text-left transition ${status === '' ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 bg-white hover:border-slate-300'}`}
          >
            <p className="text-xs text-slate-500">Semua</p>
            <p className="text-lg font-bold text-slate-900">
              {summary ? STATUSES.reduce((n, s) => n + summary[s].count, 0) : '—'}
            </p>
          </button>
          {STATUSES.map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => filter(() => setStatus(s))}
              className={`rounded-xl border p-3 text-left transition ${status === s ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 bg-white hover:border-slate-300'}`}
            >
              <p className="text-xs text-slate-500">{TOPUP_STATUS[s].label}</p>
              <p className="text-lg font-bold text-slate-900">{summary ? summary[s].count : '—'}</p>
              <p className="text-xs text-slate-500">{summary ? rupiah(summary[s].total) : ''}</p>
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="relative min-w-[240px] flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className={`${input} w-full pl-9`}
              placeholder="Cari no. top up, nama, email, atau no. HP"
              value={search}
              onChange={(e) => filter(() => setSearch(e.target.value))}
            />
          </div>
          <input type="date" className={input} value={dateFrom} onChange={(e) => filter(() => setDateFrom(e.target.value))} aria-label="Dari tanggal" />
          <span className="text-sm text-slate-400">s/d</span>
          <input type="date" className={input} value={dateTo} onChange={(e) => filter(() => setDateTo(e.target.value))} aria-label="Sampai tanggal" />
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : rows.length === 0 ? (
            <p className="p-10 text-center text-sm text-slate-400">Tidak ada top up.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">No. Top Up</th>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Metode</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Waktu</th>
                  <th className="px-4 py-3 text-right">Nominal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((r) => (
                  <tr key={r.id} className="cursor-pointer hover:bg-slate-50" onClick={() => setSelected(r.id)}>
                    <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-slate-700">{r.topup_number}</td>
                    <td className="px-4 py-3">
                      <p className="font-medium text-slate-800">{r.user?.name ?? '—'}</p>
                      <p className="text-xs text-slate-500">{r.user?.email || r.user?.phone}</p>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{r.payment_method ?? <span className="text-slate-400">Belum dipilih</span>}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={r.status} />
                      {r.status === 'pending' && r.payment_expires_at && (
                        <p className="mt-1 text-[11px] text-slate-400">Batas {formatDateTime(r.payment_expires_at)}</p>
                      )}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-500">{formatDateTime(r.paid_at ?? r.created_at)}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-right font-semibold text-slate-900">{rupiah(r.amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {meta && meta.last_page > 1 && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Halaman {meta.current_page} dari {meta.last_page} · {meta.total} top up
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
      </div>

      {selected && <TopupDrawer id={selected} onClose={() => setSelected(null)} onChanged={load} />}
    </AdminLayout>
  );
}

function TopupDrawer({ id, onClose, onChanged }: { id: string; onClose: () => void; onChanged: () => void }) {
  const [detail, setDetail] = useState<WalletTopupDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [copied, setCopied] = useState<string | null>(null);

  // The backend re-checks a running top-up with Midtrans on every fetch.
  const load = useCallback(async () => {
    setRefreshing(true);
    setError(null);
    try {
      const next = await apiRequest<WalletTopupDetail>(`/admin/wallet-topups/${id}`);
      setDetail((prev) => {
        if (prev && prev.status !== next.status) onChanged();
        return next;
      });
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat detail top up.');
    } finally {
      setRefreshing(false);
    }
  }, [id, onChanged]);

  useEffect(() => {
    const t = setTimeout(load, 0);
    return () => clearTimeout(t);
  }, [load]);

  const copy = async (value: string) => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(value);
      setTimeout(() => setCopied(null), 1500);
    } catch {
      /* clipboard blocked */
    }
  };

  const row = (label: string, value: React.ReactNode) => (
    <div className="flex items-start justify-between gap-4 py-2 text-sm">
      <span className="text-slate-500">{label}</span>
      <span className="text-right font-medium text-slate-800">{value}</span>
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-slate-900/40" onClick={onClose}>
      <div className="flex h-full w-full max-w-lg flex-col bg-white shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between border-b border-slate-100 p-5">
          <div>
            <p className="text-xs text-slate-500">Detail Top Up</p>
            <p className="font-mono text-base font-bold text-slate-900">{detail?.topup_number ?? 'Memuat…'}</p>
          </div>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={load}
              disabled={refreshing}
              title="Cek ulang status ke Midtrans"
              className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
            </button>
            <button type="button" onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>

        <div className="flex-1 space-y-5 overflow-y-auto p-5">
          {error && (
            <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
              <AlertCircle className="h-4 w-4" /> {error}
            </div>
          )}

          {!detail ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : (
            <>
              <div className="rounded-xl bg-gradient-to-br from-teal-600 to-sky-600 p-4 text-white">
                <div className="flex items-center justify-between">
                  <p className="text-xs opacity-80">Nominal top up</p>
                  <StatusBadge status={detail.status} />
                </div>
                <p className="text-2xl font-extrabold">{rupiah(detail.amount)}</p>
                {detail.balance_after !== null && (
                  <p className="mt-1 text-xs opacity-80">Saldo customer setelah top up: {rupiah(detail.balance_after)}</p>
                )}
              </div>

              <section>
                <p className="mb-1 text-sm font-semibold text-slate-800">Pembayaran</p>
                <div className="divide-y divide-slate-100 rounded-xl border border-slate-200 px-4">
                  {row('Metode pembayaran', detail.payment_method ?? <span className="text-slate-400">Belum dipilih customer</span>)}
                  {detail.payment_fields.map((f) =>
                    row(
                      f.label,
                      <button
                        type="button"
                        onClick={() => copy(f.value)}
                        className="inline-flex items-center gap-1.5 break-all text-right hover:text-emerald-700"
                        title="Salin"
                      >
                        {f.value}
                        {copied === f.value ? (
                          <Check className="h-3.5 w-3.5 shrink-0 text-emerald-600" />
                        ) : (
                          <Copy className="h-3.5 w-3.5 shrink-0 text-slate-300" />
                        )}
                      </button>
                    )
                  )}
                </div>
                {detail.status === 'pending' && !detail.payment_method && (
                  <p className="mt-2 text-xs text-slate-500">
                    Customer belum memilih metode di halaman Midtrans, jadi nomor VA / kode bayar belum tersedia.
                  </p>
                )}
                {detail.payment_redirect_url && (
                  <a
                    href={detail.payment_redirect_url}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline"
                  >
                    Buka halaman pembayaran Midtrans <ExternalLink className="h-3 w-3" />
                  </a>
                )}
              </section>

              <section>
                <p className="mb-1 text-sm font-semibold text-slate-800">Customer</p>
                <div className="divide-y divide-slate-100 rounded-xl border border-slate-200 px-4">
                  {row('Nama', detail.user?.name ?? '—')}
                  {detail.user?.email && row('Email', detail.user.email)}
                  {detail.user?.phone && row('No. HP', detail.user.phone)}
                  {detail.user && row('Saldo saat ini', rupiah(detail.user.balance))}
                </div>
              </section>

              <section>
                <p className="mb-1 text-sm font-semibold text-slate-800">Waktu</p>
                <div className="divide-y divide-slate-100 rounded-xl border border-slate-200 px-4">
                  {row('Dibuat', formatDateTime(detail.created_at))}
                  {detail.paid_at && row('Dibayar', formatDateTime(detail.paid_at))}
                  {detail.status === 'pending' && detail.payment_expires_at && row('Batas pembayaran', formatDateTime(detail.payment_expires_at))}
                  {row('Terakhir diperbarui', formatDateTime(detail.updated_at))}
                </div>
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
