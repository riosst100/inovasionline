'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { formatDateTime } from '../../../lib/date';
import AdminLayout from '../../../components/layout/AdminLayout';
import { useAuth } from '../../../context/AuthContext';
import { adminApi, ApiError } from '../../../lib/api';
import { AdminSession } from '../../../types';
import { AlertCircle, CheckCircle2, Loader2, LogOut, Monitor, Smartphone } from 'lucide-react';

function timeAgo(iso: string | null): string {
  if (!iso) return '-';
  const diff = Math.max(0, Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'Baru saja';
  if (diff < 3600) return `${Math.floor(diff / 60)} menit lalu`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`;
  return `${Math.floor(diff / 86400)} hari lalu`;
}

export default function AdminSessionsPage() {
  const { logout } = useAuth();
  const [sessions, setSessions] = useState<AdminSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<number | 'others' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setSessions(await adminApi.getSessions());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat sesi.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const run = async (key: number | 'others', action: () => Promise<unknown>, okMsg: string) => {
    setBusyId(key);
    setError(null);
    setSuccess(null);
    try {
      await action();
      setSuccess(okMsg);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Terjadi kesalahan.');
    } finally {
      setBusyId(null);
    }
  };

  const revoke = (s: AdminSession) => {
    if (s.is_current) {
      if (!confirm('Ini sesi perangkat Anda saat ini. Anda akan logout. Lanjutkan?')) return;
      logout();
      return;
    }
    run(s.id, () => adminApi.revokeSession(s.id), 'Sesi berhasil dihentikan.');
  };

  const others = sessions.filter((s) => !s.is_current).length;

  return (
    <AdminLayout>
      <div className="mx-auto max-w-4xl space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Sesi &amp; Perangkat</h1>
            <p className="text-sm text-slate-500">
              Perangkat yang sedang login ke akun Anda. Sesi bertahan hingga 1 tahun selama tidak dihentikan.
            </p>
          </div>
          {others > 0 && (
            <button
              onClick={() =>
                confirm(`Hentikan ${others} sesi lain?`) &&
                run('others', () => adminApi.revokeOtherSessions(), 'Semua sesi lain dihentikan.')
              }
              disabled={busyId !== null}
              className="inline-flex items-center gap-2 rounded-xl bg-rose-600 px-4 py-2 text-sm font-semibold text-white hover:bg-rose-700 disabled:opacity-50"
            >
              {busyId === 'others' ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogOut className="h-4 w-4" />}
              Keluar dari semua perangkat lain
            </button>
          )}
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

        <div className="divide-y divide-slate-100 rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : sessions.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Tidak ada sesi aktif.</p>
          ) : (
            sessions.map((s) => {
              const mobile = /Android|iOS/.test(s.device);
              const Icon = mobile ? Smartphone : Monitor;
              return (
                <div key={s.id} className="flex items-center gap-4 p-4">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-600">
                    <Icon className="h-5 w-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-semibold text-slate-900">{s.device}</span>
                      {s.is_current && (
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-[11px] font-semibold text-emerald-700">
                          Perangkat ini
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-slate-500">
                      Terakhir aktif {timeAgo(s.last_active_at)}
                      {s.ip_address ? ` · IP ${s.ip_address}` : ''}
                    </p>
                    <p className="text-xs text-slate-400">
                      Login{' '}
                      {formatDateTime(s.created_at)}
                    </p>
                  </div>
                  <button
                    onClick={() => revoke(s)}
                    disabled={busyId !== null}
                    className="rounded-lg border border-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-50"
                  >
                    {busyId === s.id ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Keluarkan'}
                  </button>
                </div>
              );
            })
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
