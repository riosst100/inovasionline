'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { AppUpdateOverview, AppUpdateSettings } from '../../../../types';
import { AlertCircle, AlertTriangle, CheckCircle2, Loader2, Save } from 'lucide-react';

const DEFAULTS: AppUpdateSettings = { min_build_number: 0, message: null };

export default function AppUpdatePage() {
  const [form, setForm] = useState<AppUpdateSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [overview, setOverview] = useState<AppUpdateOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = (res: AppUpdateOverview) => {
    setOverview(res);
    const clean: AppUpdateSettings = { min_build_number: res.min_build_number, message: res.message };
    setForm(clean);
    setInitial(JSON.stringify(clean));
  };

  useEffect(() => {
    (async () => {
      try {
        load(await adminApi.getAppUpdate());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan update aplikasi.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const set = <K extends keyof AppUpdateSettings>(key: K, value: AppUpdateSettings[K]) => {
    setSuccess(null);
    setForm((f) => ({ ...f, [key]: value }));
  };

  const dirty = JSON.stringify(form) !== initial;
  const builds = overview?.builds ?? [];
  const latestBuild = builds[0]?.build_number ?? null;
  const total = builds.reduce((sum, b) => sum + b.installs, 0);
  const affected = builds.filter((b) => b.build_number < form.min_build_number).reduce((sum, b) => sum + b.installs, 0);

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      load(await adminApi.saveAppUpdate({ ...form, message: form.message?.trim() || null }));
      setSuccess('Pengaturan disimpan. Berlaku saat aplikasi dibuka berikutnya.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan pengaturan update aplikasi.'
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
            <h1 className="text-2xl font-bold text-slate-900">Update Aplikasi</h1>
            <p className="text-sm text-slate-500">
              Update dari Google Play biasanya opsional. Kalau ada bug, naikkan build minimum supaya versi lama wajib
              update sebelum bisa dipakai.
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
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">Build minimum (wajib update)</label>
                <input
                  type="number"
                  min={0}
                  className={input}
                  value={form.min_build_number}
                  onChange={(e) => set('min_build_number', Math.max(0, Number(e.target.value) || 0))}
                />
                <p className="mt-1 text-xs text-slate-500">
                  Aplikasi dengan build di bawah angka ini wajib update. Isi <b>0</b> agar semua update opsional.
                  {latestBuild !== null && (
                    <>
                      {' '}Build terbaru yang aktif: <b>{latestBuild}</b>.{' '}
                      <button
                        type="button"
                        className="font-semibold text-emerald-600 hover:underline"
                        onClick={() => set('min_build_number', latestBuild)}
                      >
                        Wajibkan semua ke build {latestBuild}
                      </button>
                    </>
                  )}
                </p>
              </div>

              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">Pesan di layar update (opsional)</label>
                <textarea
                  className={input}
                  rows={2}
                  maxLength={255}
                  placeholder="Versi aplikasi kamu sudah tidak didukung. Update dulu untuk melanjutkan."
                  value={form.message ?? ''}
                  onChange={(e) => set('message', e.target.value)}
                />
                <p className="mt-1 text-xs text-slate-500">Mis. &quot;Ada perbaikan bug pembayaran, update dulu ya.&quot;</p>
              </div>

              <div className="flex gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <p>
                  Pastikan build tersebut sudah dirilis di Google Play. Pengguna hanya diblokir kalau Google Play sudah
                  menawarkan update ke HP-nya, jadi selama rilis bertahap (staged rollout) belum 100%, sebagian pengguna
                  belum terkena.
                </p>
              </div>
            </section>

            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="mb-1 text-sm font-semibold text-slate-800">Versi yang dipakai pengguna</h2>
              <p className="mb-4 text-xs text-slate-500">
                Android yang aktif {overview?.active_days ?? 30} hari terakhir.
                {form.min_build_number > 0 && total > 0 && (
                  <>
                    {' '}Dengan pengaturan ini, <b>{affected}</b> dari {total} perangkat wajib update.
                  </>
                )}
              </p>
              {builds.length === 0 ? (
                <p className="text-sm text-slate-500">Belum ada data. Data muncul setelah pengguna membuka versi aplikasi terbaru.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-slate-100 text-left text-xs text-slate-500">
                        <th className="py-2 pr-3 font-medium">Build</th>
                        <th className="py-2 pr-3 font-medium">Versi</th>
                        <th className="py-2 pr-3 text-right font-medium">Perangkat</th>
                        <th className="py-2 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {builds.map((b) => {
                        const forced = b.build_number < form.min_build_number;
                        return (
                          <tr key={b.build_number} className="border-b border-slate-50 last:border-0">
                            <td className="py-2 pr-3 font-semibold text-slate-800">{b.build_number}</td>
                            <td className="py-2 pr-3 text-slate-600">{b.version ?? '-'}</td>
                            <td className="py-2 pr-3 text-right text-slate-600">{b.installs}</td>
                            <td className="py-2">
                              <span
                                className={
                                  forced
                                    ? 'rounded-full bg-rose-50 px-2 py-0.5 text-xs font-semibold text-rose-600'
                                    : 'rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-600'
                                }
                              >
                                {forced ? 'Wajib update' : 'Boleh dipakai'}
                              </span>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
