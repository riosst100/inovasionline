'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { AdmobSettings } from '../../../../types';
import { AlertCircle, Check, CheckCircle2, Copy, Loader2, Save, Smartphone } from 'lucide-react';

const DEFAULTS: AdmobSettings = {
  is_active: false,
  android_banner_id: null,
  ios_banner_id: null,
  android_interstitial_id: null,
  ios_interstitial_id: null,
  android_rewarded_id: null,
  ios_rewarded_id: null,
  home_banner: true,
  home_bottom_banner: true,
  product_list_banner: true,
  product_detail_banner: true,
  interstitial_enabled: false,
  interstitial_every: 5,
  bonus_requires_ad: false,
  android_native_id: null,
  ios_native_id: null,
  posts_native_every: 6,
};

type UnitKey =
  | 'android_banner_id'
  | 'ios_banner_id'
  | 'android_interstitial_id'
  | 'ios_interstitial_id'
  | 'android_rewarded_id'
  | 'ios_rewarded_id'
  | 'android_native_id'
  | 'ios_native_id';

type ToggleKey =
  | 'home_banner'
  | 'home_bottom_banner'
  | 'product_list_banner'
  | 'product_detail_banner'
  | 'interstitial_enabled'
  | 'bonus_requires_ad';

const UNIT_FIELDS: { title: string; android: UnitKey; ios: UnitKey }[] = [
  { title: 'Banner', android: 'android_banner_id', ios: 'ios_banner_id' },
  { title: 'Native (feed Postingan)', android: 'android_native_id', ios: 'ios_native_id' },
  { title: 'Interstitial (layar penuh)', android: 'android_interstitial_id', ios: 'ios_interstitial_id' },
  { title: 'Rewarded (untuk bonus saldo)', android: 'android_rewarded_id', ios: 'ios_rewarded_id' },
];

export default function AdsensePage() {
  const [form, setForm] = useState<AdmobSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [ssvUrl, setSsvUrl] = useState('');
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = ({ ssv_callback_url, ...res }: AdmobSettings) => {
    setSsvUrl(ssv_callback_url ?? '');
    setForm(res);
    setInitial(JSON.stringify(res));
  };

  const copySsvUrl = async () => {
    try {
      await navigator.clipboard.writeText(ssvUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard blocked: the URL is selectable text anyway.
    }
  };

  useEffect(() => {
    (async () => {
      try {
        load(await adminApi.getAdmob());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan AdMob.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const set = <K extends keyof AdmobSettings>(key: K, value: AdmobSettings[K]) => {
    setSuccess(null);
    setForm((f) => ({ ...f, [key]: value }));
  };

  const dirty = JSON.stringify(form) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      load(await adminApi.saveAdmob(form));
      setSuccess('Pengaturan AdMob berhasil disimpan. Aplikasi menerapkan perubahan saat dibuka ulang.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan pengaturan AdMob.'
      );
    } finally {
      setSaving(false);
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 font-mono text-sm outline-none focus:border-emerald-500';

  const toggle = (key: ToggleKey, title: string, hint: string) => (
    <label className="flex cursor-pointer items-center justify-between gap-3">
      <div>
        <p className="text-sm font-medium text-slate-800">{title}</p>
        <p className="text-xs text-slate-500">{hint}</p>
      </div>
      <input type="checkbox" className="h-5 w-5" checked={form[key]} onChange={(e) => set(key, e.target.checked)} />
    </label>
  );

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Adsense / Admob</h1>
            <p className="text-sm text-slate-500">
              Kelola iklan Google AdMob yang tampil di aplikasi Android &amp; iOS.
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
            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <label className="flex cursor-pointer items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <Smartphone className="h-5 w-5 text-slate-400" />
                  <div>
                    <p className="text-sm font-semibold text-slate-800">Aktifkan iklan AdMob</p>
                    <p className="text-xs text-slate-500">
                      Status:{' '}
                      <span className={form.is_active ? 'font-semibold text-emerald-600' : 'font-semibold text-slate-500'}>
                        {form.is_active ? 'Iklan tampil di aplikasi' : 'Iklan tidak tampil'}
                      </span>
                    </p>
                  </div>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => set('is_active', e.target.checked)}
                />
              </label>
            </section>

            <section className="space-y-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <div>
                <h2 className="text-sm font-semibold text-slate-800">Ad Unit ID</h2>
                <p className="text-xs text-slate-500">
                  Salin dari AdMob → Apps → Ad units, format <code>ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy</code>.
                  Kosongkan untuk tidak menampilkan format tersebut di platform itu.
                </p>
              </div>
              {UNIT_FIELDS.map((f) => (
                <div key={f.title}>
                  <p className="mb-2 text-sm font-medium text-slate-700">{f.title}</p>
                  <div className="grid gap-3 sm:grid-cols-2">
                    {([['Android', f.android], ['iOS', f.ios]] as const).map(([label, key]) => (
                      <div key={key}>
                        <label className="mb-1 block text-xs text-slate-500">{label}</label>
                        <input
                          className={input}
                          placeholder="ca-app-pub-…/…"
                          value={form[key] ?? ''}
                          onChange={(e) => set(key, e.target.value.trim() || null)}
                        />
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </section>

            <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-sm font-semibold text-slate-800">Penempatan</h2>
              {toggle('home_banner', 'Banner di Beranda (bawah kategori)', 'Di antara kategori dan "Inspirasi Untukmu".')}
              {toggle('home_bottom_banner', 'Banner di paling bawah Beranda', 'Setelah daftar produk "Inspirasi Untukmu".')}
              {toggle(
                'product_list_banner',
                'Banner di listing produk',
                'Menempel di bawah layar daftar produk kategori dan hasil pencarian.'
              )}
              {toggle('product_detail_banner', 'Banner di Detail Produk', 'Di bawah deskripsi produk.')}
              {toggle('interstitial_enabled', 'Iklan layar penuh (interstitial)', 'Muncul saat membuka detail produk.')}
              {form.interstitial_enabled && (
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Tampilkan setiap <span className="text-rose-500">*</span></label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      min={1}
                      max={100}
                      className="w-24 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
                      value={form.interstitial_every}
                      onChange={(e) => set('interstitial_every', Number(e.target.value) || 1)}
                    />
                    <span className="text-sm text-slate-600">kali membuka detail produk</span>
                  </div>
                  <p className="mt-1 text-xs text-slate-500">
                    Aplikasi juga memberi jeda minimal 60 detik antar iklan layar penuh.
                  </p>
                </div>
              )}
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">Iklan native di feed Postingan <span className="text-rose-500">*</span></label>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-slate-600">Setiap</span>
                  <input
                    type="number"
                    min={0}
                    max={50}
                    className="w-24 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
                    value={form.posts_native_every}
                    onChange={(e) => set('posts_native_every', Math.max(0, Number(e.target.value) || 0))}
                  />
                  <span className="text-sm text-slate-600">postingan</span>
                </div>
                <p className="mt-1 text-xs text-slate-500">
                  Tampil seperti postingan biasa dengan label &quot;Iklan&quot;. Isi 0 untuk mematikan.
                </p>
              </div>
            </section>

            <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-sm font-semibold text-slate-800">Bonus Saldo</h2>
              {toggle(
                'bonus_requires_ad',
                'Wajib nonton iklan untuk klaim bonus saldo',
                'Saat menekan "Klaim", user diminta menonton iklan rewarded sampai selesai. Bonus baru masuk setelah Google mengonfirmasi iklan ditonton.'
              )}
              <div>
                <p className="mb-1 text-sm font-medium text-slate-700">URL verifikasi (SSV)</p>
                <div className="flex gap-2">
                  <input readOnly className={input} value={ssvUrl} onFocus={(e) => e.target.select()} />
                  <button
                    type="button"
                    onClick={copySsvUrl}
                    className="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-slate-200 px-3 text-sm text-slate-700 hover:bg-slate-50"
                  >
                    {copied ? <Check className="h-4 w-4 text-emerald-600" /> : <Copy className="h-4 w-4" />}
                    {copied ? 'Tersalin' : 'Salin'}
                  </button>
                </div>
                <p className="mt-1 text-xs text-slate-500">
                  Wajib: di AdMob buka ad unit Rewarded → Server-side verification, tempel URL ini. Tanpa ini klaim
                  bonus tidak akan pernah berhasil.
                </p>
              </div>
            </section>

            <p className="text-xs text-slate-500">
              AdMob App ID ditanam di build aplikasi (Android &amp; iOS), sehingga perubahannya perlu rilis ulang.
              Ad Unit ID dan penempatan di halaman ini berlaku tanpa rilis ulang.
            </p>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
