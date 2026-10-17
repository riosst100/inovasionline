'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { NavBadgeSettings } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Save, ShoppingBag } from 'lucide-react';

const DEFAULTS: NavBadgeSettings = {
  is_active: false,
  label: '12.12 Sale',
  starts_at: null,
  ends_at: null,
};

/** ISO string -> value for <input type="datetime-local"> in the admin's local time. */
function toLocalInput(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const fromLocalInput = (v: string): string | null => (v ? new Date(v).toISOString() : null);

function strip(s: NavBadgeSettings): NavBadgeSettings {
  const { is_visible: _ignored, ...rest } = s;
  return rest;
}

export default function NavBadgePage() {
  const [form, setForm] = useState<NavBadgeSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [visibleNow, setVisibleNow] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = (res: NavBadgeSettings) => {
    setVisibleNow(!!res.is_visible);
    const clean = strip(res);
    setForm(clean);
    setInitial(JSON.stringify(clean));
  };

  useEffect(() => {
    (async () => {
      try {
        load(await adminApi.getNavBadge());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan badge.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const set = <K extends keyof NavBadgeSettings>(key: K, value: NavBadgeSettings[K]) => {
    setSuccess(null);
    setForm((f) => ({ ...f, [key]: value }));
  };

  const dirty = JSON.stringify(form) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      load(await adminApi.saveNavBadge(form));
      setSuccess('Badge menu berhasil disimpan. Aplikasi menampilkan perubahan saat dibuka ulang.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan badge menu.'
      );
    } finally {
      setSaving(false);
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Badge Menu</h1>
            <p className="text-sm text-slate-500">
              Label promo di menu &quot;Belanja Online&quot; pada bottom navigation aplikasi, mis. untuk kampanye 12.12.
            </p>
          </div>
          <button
            type="button"
            onClick={save}
            disabled={saving || loading || !dirty}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            Simpan
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
          <>
            <section className="space-y-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <label className="flex cursor-pointer items-center justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold text-slate-800">Tampilkan badge</p>
                  <p className="text-xs text-slate-500">
                    Status saat ini:{' '}
                    <span className={visibleNow ? 'font-semibold text-emerald-600' : 'font-semibold text-slate-500'}>
                      {visibleNow ? 'Tampil di aplikasi' : 'Tidak tampil'}
                    </span>
                  </p>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => set('is_active', e.target.checked)}
                />
              </label>

              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">Teks badge</label>
                <input
                  className={input}
                  maxLength={16}
                  value={form.label}
                  onChange={(e) => set('label', e.target.value)}
                />
                <p className="mt-1 text-xs text-slate-500">Maksimal 16 karakter. Teks pendek lebih mudah terbaca.</p>
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Mulai tampil (opsional)</label>
                  <input
                    type="datetime-local"
                    className={input}
                    value={toLocalInput(form.starts_at)}
                    onChange={(e) => set('starts_at', fromLocalInput(e.target.value))}
                  />
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Selesai tampil (opsional)</label>
                  <input
                    type="datetime-local"
                    className={input}
                    value={toLocalInput(form.ends_at)}
                    onChange={(e) => set('ends_at', fromLocalInput(e.target.value))}
                  />
                </div>
              </div>
              <p className="-mt-2 text-xs text-slate-500">
                Kosongkan untuk tampil tanpa batas waktu. Badge otomatis hilang setelah waktu selesai.
              </p>
            </section>

            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="mb-1 text-sm font-semibold text-slate-800">Pratinjau</h2>
              <p className="mb-4 text-xs text-slate-500">Gaya badge (oranye dengan efek kilau) sudah diatur di aplikasi.</p>
              {/* Mirrors the app's sweep: 3.2s cycle, shine during the first ~30%. */}
              <style>{`
                .nav-badge-shine { position: absolute; }
                .nav-badge-shine::after {
                  content: ''; position: absolute; inset: 0;
                  background: linear-gradient(90deg, transparent 35%, rgba(255,255,255,.55) 50%, transparent 65%);
                  transform: translateX(-100%);
                  animation: nav-badge-sweep 3.2s linear infinite;
                }
                @keyframes nav-badge-sweep {
                  0% { transform: translateX(-100%); }
                  30%, 100% { transform: translateX(100%); }
                }
                @media (prefers-reduced-motion: reduce) { .nav-badge-shine::after { animation: none; display: none; } }
              `}</style>
              <div className="flex justify-center rounded-xl bg-slate-50 py-8">
                <div className="flex flex-col items-center gap-1">
                  <div className="relative">
                    <div className="flex h-[42px] w-[42px] items-center justify-center rounded-full border border-sky-200 bg-sky-50">
                      <ShoppingBag className="h-6 w-6 text-sky-400" />
                    </div>
                    {form.is_active && form.label.trim() !== '' && (
                      <span className="nav-badge-shine absolute -bottom-1 left-1/2 -translate-x-1/2 overflow-hidden whitespace-nowrap rounded-full border border-white bg-[#FA6E1D] px-1.5 text-[8px] font-extrabold leading-[10px] text-white shadow-sm">
                        {form.label}
                      </span>
                    )}
                  </div>
                  <span className="text-[10px] font-medium text-slate-500">Belanja Online</span>
                </div>
              </div>
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
