'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest, apiRequestFull, ApiError } from '../../../lib/api';
import { formatDateTime } from '../../../lib/date';
import { CodVerificationRow, CodVerificationStatus, PaginationMeta } from '../../../types';
import { AlertCircle, ChevronLeft, ChevronRight, Filter, Loader2, ScanFace, Search, ShieldOff, X } from 'lucide-react';

const STATUS: Record<CodVerificationStatus, { label: string; badge: string }> = {
  verified: { label: 'Terverifikasi', badge: 'bg-emerald-50 text-emerald-700 ring-emerald-200' },
  revoked: { label: 'Dicabut', badge: 'bg-rose-50 text-rose-700 ring-rose-200' },
};

const STEP_LABEL: Record<string, string> = {
  come_closer: 'Dekatkan wajah',
  turn_right: 'Tengok kanan',
  turn_left: 'Tengok kiri',
  nod: 'Mengangguk',
  blink: 'Kedip mata',
  color_check: 'Cek warna',
};

function StatusBadge({ status }: { status: CodVerificationStatus }) {
  const s = STATUS[status];
  return <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ${s.badge}`}>{s.label}</span>;
}

export default function CodVerificationsPage() {
  const [rows, setRows] = useState<CodVerificationRow[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<CodVerificationStatus | ''>('');
  const [search, setSearch] = useState('');
  const [customer, setCustomer] = useState<NonNullable<CodVerificationRow['user']> | null>(null);
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<CodVerificationRow | null>(null);

  const filterCustomer = (user: CodVerificationRow['user']) => {
    setCustomer(user);
    setSearch('');
    setPage(1);
  };

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ per_page: '20', page: String(page) });
      if (status) params.set('status', status);
      if (customer) params.set('user_id', customer.id);
      else if (search.trim()) params.set('search', search.trim());
      const res = await apiRequestFull<CodVerificationRow[]>(`/admin/cod-verifications?${params}`);
      setRows(res.data ?? []);
      setMeta(res.meta ?? null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat verifikasi pengguna.');
    } finally {
      setLoading(false);
    }
  }, [status, search, customer, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  // ?event=<id> (linked from the customer list): show that customer's events with this one open.
  useEffect(() => {
    const eventId = new URLSearchParams(window.location.search).get('event');
    if (!eventId) return;
    apiRequestFull<CodVerificationRow[]>(`/admin/cod-verifications?id=${encodeURIComponent(eventId)}`)
      .then((res) => {
        const row = res.data?.[0];
        if (!row) return;
        if (row.user) filterCustomer(row.user);
        setSelected(row);
      })
      .catch(() => {});
  }, []);

  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <ScanFace className="h-6 w-6 text-emerald-600" />
            <h1 className="text-2xl font-bold text-slate-900">Verifikasi Pengguna</h1>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Rekaman verifikasi wajah customer sebelum memakai pembayaran di tempat (COD). Cukup dilakukan sekali; cabut
            verifikasi jika rekaman mencurigakan agar customer wajib mengulang.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {customer ? (
            <div className="flex min-w-[240px] flex-1 items-center gap-2">
              <span className="inline-flex items-center gap-2 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
                <Filter className="h-4 w-4" />
                Customer: <b>{customer.name}</b>
                <span className="text-emerald-600">{customer.email || customer.phone}</span>
                <button onClick={() => filterCustomer(null)} aria-label="Hapus filter customer" className="rounded p-0.5 hover:bg-emerald-100">
                  <X className="h-4 w-4" />
                </button>
              </span>
            </div>
          ) : (
            <div className="relative min-w-[240px] flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                className={`${input} w-full pl-9`}
                placeholder="Cari nama, email, atau no. HP"
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setPage(1);
                }}
              />
            </div>
          )}
          <select
            className={input}
            value={status}
            onChange={(e) => {
              setStatus(e.target.value as CodVerificationStatus | '');
              setPage(1);
            }}
          >
            <option value="">Semua status</option>
            <option value="verified">Terverifikasi</option>
            <option value="revoked">Dicabut</option>
          </select>
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
            <p className="p-10 text-center text-sm text-slate-400">Belum ada verifikasi pengguna.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Perangkat</th>
                  <th className="px-4 py-3">Waktu</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((r) => (
                  <tr key={r.id} className="cursor-pointer hover:bg-slate-50" onClick={() => setSelected(r)}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div>
                          <p className="font-medium text-slate-800">{r.user?.name ?? '—'}</p>
                          <p className="text-xs text-slate-500">{r.user?.email || r.user?.phone}</p>
                        </div>
                        {r.user && !customer && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              filterCustomer(r.user);
                            }}
                            title="Tampilkan hanya customer ini"
                            aria-label="Filter customer ini"
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-emerald-50 hover:text-emerald-700"
                          >
                            <Filter className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={r.status} />
                    </td>
                    <td className="px-4 py-3 text-slate-600">{r.device ?? '—'}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-500">{formatDateTime(r.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {meta && meta.last_page > 1 && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Halaman {meta.current_page} dari {meta.last_page} · {meta.total} rekaman
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

      {selected && (
        <ReviewDrawer
          row={selected}
          onClose={() => setSelected(null)}
          onFilterCustomer={
            selected.user && !customer
              ? () => {
                  filterCustomer(selected.user);
                  setSelected(null);
                }
              : undefined
          }
          onChanged={(next) => {
            setSelected(next);
            load();
          }}
        />
      )}
    </AdminLayout>
  );
}

function ReviewDrawer({
  row,
  onClose,
  onFilterCustomer,
  onChanged,
}: {
  row: CodVerificationRow;
  onClose: () => void;
  /** Show this customer's other verifications in the list */
  onFilterCustomer?: () => void;
  onChanged: (next: CodVerificationRow) => void;
}) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const revoke = async () => {
    if (!reason.trim()) {
      setError('Alasan pencabutan wajib diisi.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const next = await apiRequest<CodVerificationRow>(`/admin/cod-verifications/${row.id}/revoke`, {
        method: 'POST',
        body: JSON.stringify({ reason: reason.trim() }),
      });
      onChanged(next);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal mencabut verifikasi.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-slate-900/40" onClick={onClose}>
      <div className="h-full w-full max-w-md overflow-y-auto bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="mb-4 flex items-start justify-between">
          <div>
            <h2 className="text-lg font-bold text-slate-900">{row.user?.name ?? 'Customer'}</h2>
            <p className="text-sm text-slate-500">{row.user?.email || row.user?.phone}</p>
            {onFilterCustomer && (
              <button
                onClick={onFilterCustomer}
                className="mt-1 inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline"
              >
                <Filter className="h-3.5 w-3.5" /> Lihat semua verifikasi customer ini
              </button>
            )}
          </div>
          <button onClick={onClose} aria-label="Tutup" className="rounded-lg p-1.5 hover:bg-slate-100">
            <X className="h-5 w-5" />
          </button>
        </div>

        <video
          key={row.video_url}
          src={row.video_url}
          controls
          playsInline
          preload="metadata"
          className="aspect-[3/4] w-full rounded-xl bg-black object-contain"
        />

        <dl className="mt-4 space-y-2 text-sm">
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Status</dt>
            <dd>
              <StatusBadge status={row.status} />
            </dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Direkam</dt>
            <dd className="text-slate-800">{formatDateTime(row.created_at)}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Perangkat / IP</dt>
            <dd className="text-slate-800">
              {row.device ?? '—'} · {row.ip_address ?? '—'}
            </dd>
          </div>
        </dl>

        <div className="mt-4 flex flex-wrap gap-1.5">
          {row.steps.map((s) => (
            <span key={s} className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
              ✓ {STEP_LABEL[s] ?? s}
            </span>
          ))}
        </div>

        {row.status === 'revoked' ? (
          <div className="mt-5 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-800">
            <p className="font-semibold">Dicabut {row.revoked_at ? formatDateTime(row.revoked_at) : ''}</p>
            <p className="mt-1">{row.revoked_reason}</p>
          </div>
        ) : (
          <div className="mt-5 space-y-2">
            <label className="text-sm font-medium text-slate-700" htmlFor="revoke-reason">
              Cabut verifikasi <span className="text-rose-500">*</span>
            </label>
            <textarea
              id="revoke-reason"
              rows={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Alasan, mis. wajah tidak sesuai atau rekaman tidak valid"
              className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-rose-400"
            />
            {error && <p className="text-sm text-rose-600">{error}</p>}
            <button
              onClick={revoke}
              disabled={busy}
              className="inline-flex items-center gap-2 rounded-lg bg-rose-600 px-4 py-2 text-sm font-semibold text-white hover:bg-rose-700 disabled:opacity-50"
            >
              {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <ShieldOff className="h-4 w-4" />}
              Cabut Verifikasi
            </button>
            <p className="text-xs text-slate-500">
              Status verifikasi customer ikut dicabut dan merujuk ke event ini. Customer harus mengulang verifikasi wajah
              sebelum memakai COD/Paylater lagi.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
