'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { formatDateTime } from '../../../../lib/date';
import { AppCacheGroup } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, RefreshCw } from 'lucide-react';

export default function AppCachePage() {
  const [groups, setGroups] = useState<AppCacheGroup[]>([]);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setGroups(await adminApi.getAppCache());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat data cache.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const toggle = (key: string) =>
    setPicked((cur) => {
      const next = new Set(cur);
      if (!next.delete(key)) next.add(key);
      return next;
    });

  const allPicked = groups.length > 0 && groups.every((g) => picked.has(g.key));

  const invalidate = async (keys: string[]) => {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      setGroups(await adminApi.invalidateAppCache(keys));
      setPicked(new Set());
      setSuccess(`${keys.length} cache disegarkan. Aplikasi mengambil data barunya saat dibuka berikutnya.`);
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyegarkan cache.'
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Cache Aplikasi</h1>
            <p className="text-sm text-slate-500">
              Aplikasi menyimpan beberapa data di HP dan tidak memintanya lagi ke server selama belum berubah. Data
              ini disegarkan otomatis saat diubah dari admin; gunakan halaman ini bila perlu memaksa aplikasi
              mengambil ulang, mis. setelah mengubah data langsung di database.
            </p>
          </div>
          <button
            type="button"
            onClick={() => invalidate(groups.filter((g) => picked.has(g.key)).map((g) => g.key))}
            disabled={busy || loading || picked.size === 0}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
            Segarkan terpilih{picked.size > 0 ? ` (${picked.size})` : ''}
          </button>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        {loading ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <section className="rounded-2xl border border-slate-200 bg-white shadow-sm">
            <label className="flex cursor-pointer items-center gap-3 border-b border-slate-100 px-4 py-3">
              <input
                type="checkbox"
                checked={allPicked}
                ref={(el) => {
                  if (el) el.indeterminate = picked.size > 0 && !allPicked;
                }}
                onChange={() => setPicked(allPicked ? new Set() : new Set(groups.map((g) => g.key)))}
              />
              <span className="flex-1 text-sm font-semibold text-slate-800">Pilih semua</span>
              <button
                type="button"
                disabled={busy}
                onClick={(e) => {
                  e.preventDefault();
                  invalidate(groups.map((g) => g.key));
                }}
                className="rounded-lg border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-50 disabled:opacity-50"
              >
                Segarkan semua
              </button>
            </label>

            <ul className="divide-y divide-slate-100">
              {groups.map((g) => (
                <li key={g.key}>
                  <label
                    className={`flex cursor-pointer items-start gap-3 px-4 py-3 ${
                      picked.has(g.key) ? 'bg-emerald-50' : 'hover:bg-slate-50'
                    }`}
                  >
                    <input
                      type="checkbox"
                      className="mt-1"
                      checked={picked.has(g.key)}
                      onChange={() => toggle(g.key)}
                    />
                    <span className="flex-1">
                      <span className="block text-sm font-semibold text-slate-800">{g.label}</span>
                      <span className="block text-xs text-slate-500">{g.description}</span>
                    </span>
                    <span className="text-right text-xs text-slate-400">
                      <span className="block">Versi {g.version}</span>
                      <span className="block">
                        {g.updated_at ? `Diubah ${formatDateTime(g.updated_at)}` : 'Belum pernah diubah'}
                      </span>
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </AdminLayout>
  );
}
