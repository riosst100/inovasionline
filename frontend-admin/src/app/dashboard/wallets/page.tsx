'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest, apiRequestFull, ApiError } from '../../../lib/api';
import { WalletDetail, WalletRow } from '../../../types';
import { formatDateTime as formatDate, rupiah, TRANSACTION_TYPE_LABEL as TYPE_LABEL } from '../../../lib/wallet';
import { AlertCircle, Loader2, Search, Wallet, X } from 'lucide-react';

export default function WalletsPage() {
  const [rows, setRows] = useState<WalletRow[]>([]);
  const [totalBalance, setTotalBalance] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [onlyWithBalance, setOnlyWithBalance] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<WalletRow | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ per_page: '50' });
      if (search.trim()) params.set('search', search.trim());
      if (onlyWithBalance) params.set('has_balance', '1');
      const res = await apiRequestFull<WalletRow[]>(`/admin/wallets?${params}`);
      setRows(res.data ?? []);
      setTotalBalance(Number((res.meta as Record<string, unknown> | undefined)?.total_balance ?? 0));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat data saldo.');
    } finally {
      setLoading(false);
    }
  }, [search, onlyWithBalance]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Wallet className="h-6 w-6 text-emerald-600" />
              <h1 className="text-2xl font-bold text-slate-900">Saldo Pengguna</h1>
            </div>
            <p className="mt-1 text-sm text-slate-500">
              Saldo Inovasi customer: top up via Midtrans, dipakai saat checkout, dan menerima pengembalian dana
              pesanan yang dibatalkan. Saldo tidak dapat ditarik.
            </p>
          </div>
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2 text-right">
            <p className="text-xs text-emerald-700">Total saldo mengendap</p>
            <p className="text-lg font-bold text-emerald-800">{rupiah(totalBalance)}</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="relative min-w-[240px] flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="w-full rounded-lg border border-slate-200 bg-white py-2 pl-9 pr-3 text-sm outline-none focus:border-emerald-500"
              placeholder="Cari nama, email, atau no. HP"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <label className="flex cursor-pointer items-center gap-2 text-sm text-slate-600">
            <input type="checkbox" checked={onlyWithBalance} onChange={(e) => setOnlyWithBalance(e.target.checked)} />
            Hanya yang punya saldo
          </label>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : rows.length === 0 ? (
            <p className="p-10 text-center text-sm text-slate-400">Tidak ada data.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Kontak</th>
                  <th className="px-4 py-3 text-right">Saldo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((r) => (
                  <tr key={r.id} className="cursor-pointer hover:bg-slate-50" onClick={() => setSelected(r)}>
                    <td className="px-4 py-3 font-medium text-slate-800">{r.name}</td>
                    <td className="px-4 py-3 text-slate-500">{r.email || r.phone || '-'}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-900">{rupiah(r.balance)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {selected && (
        <WalletDrawer
          userId={selected.id}
          onClose={() => setSelected(null)}
          onChanged={load}
        />
      )}
    </AdminLayout>
  );
}

function WalletDrawer({ userId, onClose, onChanged }: { userId: string; onClose: () => void; onChanged: () => void }) {
  const [detail, setDetail] = useState<WalletDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [direction, setDirection] = useState<'credit' | 'debit'>('credit');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    try {
      setDetail(await apiRequest<WalletDetail>(`/admin/wallets/${userId}?per_page=50`));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat riwayat saldo.');
    }
  }, [userId]);

  useEffect(() => {
    load();
  }, [load]);

  const value = Number(amount);
  const valid = value > 0 && description.trim().length > 0;

  const submit = async () => {
    if (!valid || !detail) return;
    const signed = direction === 'credit' ? value : -value;
    if (!confirm(`${direction === 'credit' ? 'Tambah' : 'Kurangi'} saldo ${detail.user.name} sebesar ${rupiah(value)}?`)) return;

    setSaving(true);
    setError(null);
    try {
      await apiRequest('/admin/wallets/' + userId + '/adjust', {
        method: 'POST',
        body: JSON.stringify({ amount: signed, description: description.trim() }),
      });
      setAmount('');
      setDescription('');
      await load();
      onChanged();
    } catch (e) {
      setError(
        e instanceof ApiError ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message : 'Gagal menyesuaikan saldo.'
      );
    } finally {
      setSaving(false);
    }
  };

  const input = 'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-slate-900/40" onClick={onClose}>
      <div className="flex h-full w-full max-w-lg flex-col bg-white shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between border-b border-slate-100 p-5">
          <div>
            <p className="text-lg font-bold text-slate-900">{detail?.user.name ?? 'Memuat…'}</p>
            <p className="text-xs text-slate-500">{detail?.user.email || detail?.user.phone}</p>
          </div>
          <button type="button" onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 space-y-5 overflow-y-auto p-5">
          <div className="rounded-xl bg-gradient-to-br from-teal-600 to-sky-600 p-4 text-white">
            <p className="text-xs opacity-80">Saldo saat ini</p>
            <p className="text-2xl font-extrabold">{detail ? rupiah(detail.balance) : '—'}</p>
          </div>

          {error && (
            <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
              <AlertCircle className="h-4 w-4" /> {error}
            </div>
          )}

          <section className="space-y-3 rounded-xl border border-slate-200 p-4">
            <p className="text-sm font-semibold text-slate-800">Penyesuaian manual</p>
            <div className="flex gap-2">
              {(['credit', 'debit'] as const).map((d) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => setDirection(d)}
                  className={`flex-1 rounded-lg border px-3 py-1.5 text-sm font-medium ${
                    direction === d
                      ? d === 'credit'
                        ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                        : 'border-rose-500 bg-rose-50 text-rose-700'
                      : 'border-slate-200 text-slate-500'
                  }`}
                >
                  {d === 'credit' ? '+ Tambah saldo' : '− Kurangi saldo'}
                </button>
              ))}
            </div>
            <input
              type="number"
              min={1}
              className={input}
              placeholder="Nominal (Rp)"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
            <input
              className={input}
              maxLength={255}
              placeholder="Alasan (wajib), mis. kompensasi keterlambatan"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
            <button
              type="button"
              onClick={submit}
              disabled={!valid || saving}
              className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
            >
              {saving && <Loader2 className="h-4 w-4 animate-spin" />}
              Simpan penyesuaian
            </button>
            <p className="text-xs text-slate-500">Setiap penyesuaian tercatat di riwayat beserta nama admin.</p>
          </section>

          <section>
            <p className="mb-2 text-sm font-semibold text-slate-800">Riwayat</p>
            {!detail ? (
              <div className="flex justify-center p-6">
                <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
              </div>
            ) : detail.transactions.length === 0 ? (
              <p className="py-6 text-center text-sm text-slate-400">Belum ada transaksi.</p>
            ) : (
              <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                {detail.transactions.map((t) => (
                  <div key={t.id} className="flex items-start justify-between gap-3 p-3 text-sm">
                    <div className="min-w-0">
                      <p className="font-medium text-slate-800">{TYPE_LABEL[t.type] ?? t.type}</p>
                      <p className="truncate text-xs text-slate-500">{t.description}</p>
                      <p className="text-xs text-slate-400">
                        {formatDate(t.created_at)}
                        {t.admin ? ` · oleh ${t.admin.name}` : ''}
                      </p>
                    </div>
                    <div className="shrink-0 text-right">
                      <p className={`font-semibold ${t.amount >= 0 ? 'text-emerald-600' : 'text-slate-800'}`}>
                        {t.amount >= 0 ? '+' : '−'}
                        {rupiah(t.amount)}
                      </p>
                      <p className="text-xs text-slate-400">Saldo {rupiah(t.balance_after)}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
