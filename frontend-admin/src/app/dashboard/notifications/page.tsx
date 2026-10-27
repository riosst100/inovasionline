'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { useAuth } from '../../../context/AuthContext';
import { adminApi, apiRequestFull, ApiError } from '../../../lib/api';
import { Customer } from '../../../types';
import { AlertCircle, Bell, CheckCircle2, Loader2, Search, Send, Users, X } from 'lucide-react';

type Target = 'all' | 'users';

export default function AdminNotificationsPage() {
  const { canManage } = useAuth();
  const canSend = canManage('notifications');

  const [target, setTarget] = useState<Target>('users');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');

  // Customer picker: the selection is kept across searches and pages.
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Map<string, string>>(new Map());

  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const query = new URLSearchParams({ page: String(page) });
      if (search.trim()) query.set('search', search.trim());
      // apiRequest unwraps to the plain row array; the page count is in `meta`.
      const res = await apiRequestFull<Customer[]>(`/admin/customers?${query.toString()}`);
      setCustomers(res.data ?? []);
      setLastPage(res.meta?.last_page ?? 1);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat daftar pengguna.');
    } finally {
      setLoading(false);
    }
  }, [search, page]);

  useEffect(() => {
    if (target !== 'users') return;
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load, target]);

  const toggle = (c: Customer) =>
    setSelected((prev) => {
      const next = new Map(prev);
      if (next.has(c.id)) next.delete(c.id);
      else next.set(c.id, c.name);
      return next;
    });

  const pageAllSelected = customers.length > 0 && customers.every((c) => selected.has(c.id));
  const togglePage = () =>
    setSelected((prev) => {
      const next = new Map(prev);
      if (pageAllSelected) customers.forEach((c) => next.delete(c.id));
      else customers.forEach((c) => next.set(c.id, c.name));
      return next;
    });

  const canSubmit =
    canSend && !sending && title.trim() !== '' && body.trim() !== '' && (target === 'all' || selected.size > 0);

  const handleSend = async () => {
    setError(null);
    setSuccess(null);
    if (target === 'all' && !window.confirm('Kirim notifikasi ini ke SEMUA pengguna aplikasi?')) return;

    setSending(true);
    try {
      const res = await adminApi.sendNotification({
        title: title.trim(),
        body: body.trim(),
        target,
        user_ids: target === 'users' ? Array.from(selected.keys()) : undefined,
      });
      setSuccess(
        target === 'all'
          ? 'Notifikasi dikirim ke semua pengguna.'
          : `Notifikasi dikirim ke ${res?.users ?? selected.size} pengguna` +
              (res && res.users_without_device > 0
                ? ` (${res.users_without_device} pengguna belum punya perangkat terdaftar).`
                : '.'),
      );
      setTitle('');
      setBody('');
      setSelected(new Map());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal mengirim notifikasi.');
    } finally {
      setSending(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex items-center gap-2">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
            <Bell className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-xl md:text-2xl font-extrabold text-slate-900 tracking-tight">Kirim Notifikasi</h1>
            <p className="text-xs md:text-sm text-slate-500 mt-0.5">
              Kirim push notification manual ke semua pengguna atau pengguna yang dipilih.
            </p>
          </div>
        </div>

        {error && (
          <div className="flex items-start gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4 mt-0.5 shrink-0" />
            <span className="flex-1">{error}</span>
            <button onClick={() => setError(null)}>
              <X className="h-4 w-4" />
            </button>
          </div>
        )}
        {success && (
          <div className="flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4 mt-0.5 shrink-0" />
            <span className="flex-1">{success}</span>
            <button onClick={() => setSuccess(null)}>
              <X className="h-4 w-4" />
            </button>
          </div>
        )}

        <div className="grid gap-6 lg:grid-cols-2">
          {/* Message */}
          <div className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5">
            <div className="flex gap-2">
              {(
                [
                  ['users', 'Pengguna tertentu'],
                  ['all', 'Semua pengguna'],
                ] as [Target, string][]
              ).map(([value, label]) => (
                <button
                  key={value}
                  onClick={() => setTarget(value)}
                  className={`flex-1 rounded-xl border px-3 py-2 text-sm font-semibold transition-colors ${
                    target === value
                      ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                      : 'border-slate-200 text-slate-600 hover:bg-slate-50'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>

            <div>
              <label className="mb-1 block text-sm font-semibold text-slate-700">Judul</label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                maxLength={255}
                placeholder="Contoh: Promo Akhir Pekan"
                className="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
              />
            </div>
            <div>
              <label className="mb-1 block text-sm font-semibold text-slate-700">Isi pesan</label>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                maxLength={1000}
                rows={5}
                placeholder="Tulis isi notifikasi..."
                className="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
              />
              <p className="mt-1 text-right text-xs text-slate-400">{body.length}/1000</p>
            </div>

            <button
              onClick={handleSend}
              disabled={!canSubmit}
              className="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:from-emerald-500 hover:to-teal-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
              {target === 'all' ? 'Kirim ke semua pengguna' : `Kirim ke ${selected.size} pengguna`}
            </button>
            {!canSend && <p className="text-xs text-rose-600">Anda tidak punya hak untuk mengirim notifikasi.</p>}
          </div>

          {/* Recipients */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            {target === 'all' ? (
              <div className="flex h-full min-h-48 flex-col items-center justify-center gap-2 text-center text-sm text-slate-500">
                <Users className="h-8 w-8 text-slate-300" />
                Notifikasi akan dikirim ke semua perangkat yang memasang aplikasi, termasuk yang belum login.
              </div>
            ) : (
              <div className="space-y-3">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <input
                    value={search}
                    onChange={(e) => {
                      setSearch(e.target.value);
                      setPage(1);
                    }}
                    placeholder="Cari nama, email, atau telepon..."
                    className="w-full rounded-xl border border-slate-200 py-2.5 pl-9 pr-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
                  />
                </div>

                <div className="flex items-center justify-between text-sm">
                  <label className="flex cursor-pointer items-center gap-2 font-medium text-slate-700">
                    <input
                      type="checkbox"
                      checked={pageAllSelected}
                      onChange={togglePage}
                      className="h-4 w-4 accent-emerald-600"
                    />
                    Pilih semua di halaman ini
                  </label>
                  <span className="text-slate-500">
                    {selected.size} dipilih
                    {selected.size > 0 && (
                      <button onClick={() => setSelected(new Map())} className="ml-2 text-rose-600 hover:underline">
                        Hapus
                      </button>
                    )}
                  </span>
                </div>

                <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                  {loading ? (
                    <div className="flex items-center justify-center gap-2 p-8 text-sm text-slate-500">
                      <Loader2 className="h-4 w-4 animate-spin" /> Memuat...
                    </div>
                  ) : customers.length === 0 ? (
                    <div className="p-8 text-center text-sm text-slate-500">Pengguna tidak ditemukan.</div>
                  ) : (
                    customers.map((c) => (
                      <label key={c.id} className="flex cursor-pointer items-center gap-3 px-3 py-2.5 hover:bg-slate-50">
                        <input
                          type="checkbox"
                          checked={selected.has(c.id)}
                          onChange={() => toggle(c)}
                          className="h-4 w-4 accent-emerald-600"
                        />
                        <div className="min-w-0">
                          <div className="truncate text-sm font-semibold text-slate-800">{c.name}</div>
                          <div className="truncate text-xs text-slate-500">{c.email}</div>
                        </div>
                      </label>
                    ))
                  )}
                </div>

                {lastPage > 1 && (
                  <div className="flex items-center justify-between text-sm">
                    <button
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                      disabled={page <= 1}
                      className="rounded-lg border border-slate-200 px-3 py-1.5 disabled:opacity-40"
                    >
                      Sebelumnya
                    </button>
                    <span className="text-slate-500">
                      {page} / {lastPage}
                    </span>
                    <button
                      onClick={() => setPage((p) => Math.min(lastPage, p + 1))}
                      disabled={page >= lastPage}
                      className="rounded-lg border border-slate-200 px-3 py-1.5 disabled:opacity-40"
                    >
                      Berikutnya
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}
