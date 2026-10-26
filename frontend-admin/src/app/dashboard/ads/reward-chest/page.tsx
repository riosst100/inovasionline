'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { AdChestSettings, WalletBonusTier } from '../../../../types';
import { AlertCircle, CheckCircle2, Gift, Loader2, Plus, Save, Trash2 } from 'lucide-react';

const rupiah = (n: number) => 'Rp' + Math.round(n).toLocaleString('id-ID');

/** Rough rewarded-ad revenue per completed view in Indonesia; check AdMob's own report. */
const REVENUE_PER_VIEW: [number, number] = [30, 80];

const DEFAULTS: AdChestSettings = {
  is_active: true,
  chests_per_day: 5,
  daily_budget: 100000,
  step: 5,
  tiers: [
    { from: 10, to: 20, weight: 85 },
    { from: 30, to: 50, weight: 13 },
    { from: 100, to: 500, weight: 2 },
  ],
};

/** Smallest and largest multiple of step inside the tier, or null if none fits. */
function tierBounds(t: WalletBonusTier, step: number): [number, number] | null {
  if (!(step > 0)) return null;
  const first = Math.ceil(t.from / step) * step;
  const last = Math.floor(t.to / step) * step;
  return first <= last ? [first, last] : null;
}

/** Only what the admin edits, so read-only figures don't mark the form dirty. */
const editable = (s: AdChestSettings): AdChestSettings => ({
  is_active: s.is_active,
  chests_per_day: s.chests_per_day,
  daily_budget: s.daily_budget,
  step: s.step,
  tiers: s.tiers,
});

export default function RewardChestPage() {
  const [form, setForm] = useState<AdChestSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(editable(DEFAULTS)));
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await adminApi.getAdChest();
        setForm(res);
        setInitial(JSON.stringify(editable(res)));
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan peti hadiah.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const update = (next: Partial<AdChestSettings>) => {
    setSuccess(null);
    setForm((f) => ({ ...f, ...next }));
  };

  const setTier = (index: number, key: keyof WalletBonusTier, value: number) =>
    update({ tiers: form.tiers.map((t, i) => (i === index ? { ...t, [key]: value } : t)) });

  const addTier = () => {
    const last = form.tiers[form.tiers.length - 1];
    const from = last ? last.to + form.step : 10;
    update({ tiers: [...form.tiers, { from, to: from + 100, weight: 0 }] });
  };

  const removeTier = (index: number) => update({ tiers: form.tiers.filter((_, i) => i !== index) });

  const totalWeight = form.tiers.reduce((sum, t) => sum + (Number(t.weight) || 0), 0);

  const summary = useMemo(() => {
    let max = 0;
    let average = 0;
    for (const t of form.tiers) {
      const bounds = tierBounds(t, form.step);
      if (!bounds || !(t.weight > 0)) continue;
      max = Math.max(max, bounds[1]);
      average += ((bounds[0] + bounds[1]) / 2) * (t.weight / 100);
    }
    const perView = average; // one ad opens one chest
    return { max, average, perView, perUserDay: average * form.chests_per_day };
  }, [form]);

  const dirty = JSON.stringify(editable(form)) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const res = await adminApi.saveAdChest(editable(form));
      setForm(res);
      setInitial(JSON.stringify(editable(res)));
      setSuccess('Peti hadiah berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan peti hadiah.'
      );
    } finally {
      setSaving(false);
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  const margin =
    summary.perView <= REVENUE_PER_VIEW[0] * 0.7
      ? { tone: 'text-emerald-700', note: 'Aman: di bawah perkiraan pendapatan iklan.' }
      : summary.perView <= REVENUE_PER_VIEW[1]
        ? { tone: 'text-amber-700', note: 'Tipis: bisa rugi kalau pendapatan iklan sedang rendah.' }
        : { tone: 'text-rose-700', note: 'Rugi: hadiah lebih besar dari perkiraan pendapatan iklan.' };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Peti Hadiah</h1>
            <p className="text-sm text-slate-500">
              Kartu di halaman utama aplikasi: setiap hari customer bisa membuka beberapa peti. Tiap peti dibuka dengan
              menonton 1 iklan rewarded sampai selesai, lalu langsung memberi saldo belanja acak sesuai rentang di bawah.
              Jatah peti reset setiap tengah malam (WIB).
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
        {!loading && form.ads_ready === false && (
          <div className="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            <span>
              Peti belum tampil di aplikasi: aktifkan AdMob dan isi Ad Unit ID Rewarded (beserta URL server-side
              verification) di{' '}
              <Link href="/dashboard/ads/adsense" className="font-semibold underline">
                Adsense / Admob
              </Link>
              .
            </span>
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
                  <p className="text-sm font-semibold text-slate-800">Aktifkan peti hadiah</p>
                  <p className="text-xs text-slate-500">Jika nonaktif, kartu &quot;Peti Hadiah Harian&quot; tidak tampil.</p>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => update({ is_active: e.target.checked })}
                />
              </label>

              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Peti per hari <span className="text-rose-500">*</span></label>
                  <input
                    type="number"
                    min={1}
                    max={20}
                    className={input}
                    value={form.chests_per_day}
                    onChange={(e) => update({ chests_per_day: Number(e.target.value) })}
                  />
                  <p className="mt-1 text-xs text-slate-500">
                    Per customer, reset tengah malam WIB. Tiap peti dibuka dengan menonton 1 iklan.
                  </p>
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Budget harian (Rp) <span className="text-rose-500">*</span></label>
                  <input
                    type="number"
                    min={0}
                    step={1000}
                    className={input}
                    value={form.daily_budget}
                    onChange={(e) => update({ daily_budget: Number(e.target.value) })}
                  />
                  <p className="mt-1 text-xs text-slate-500">
                    Total saldo dari semua peti per hari. 0 = tanpa batas. Setelah habis, customer tidak bisa mengisi peti
                    baru; peti yang sudah penuh tetap memberi hadiah terkecil.
                  </p>
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Kelipatan nominal (Rp) <span className="text-rose-500">*</span></label>
                  <input
                    type="number"
                    min={1}
                    step={5}
                    className={input}
                    value={form.step}
                    onChange={(e) => update({ step: Number(e.target.value) })}
                  />
                  <p className="mt-1 text-xs text-slate-500">
                    Contoh kelipatan {rupiah(5)}: hadiah bisa {rupiah(10)}, {rupiah(15)}, {rupiah(20)}, dst.
                  </p>
                </div>
              </div>
            </section>

            <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <h2 className="text-sm font-semibold text-slate-800">Rentang hadiah &amp; peluang</h2>
                  <p className="text-xs text-slate-500">Total persentase semua rentang harus 100%.</p>
                </div>
                <span
                  className={`rounded-full px-3 py-1 text-xs font-bold ${
                    totalWeight === 100 ? 'bg-emerald-50 text-emerald-700' : 'bg-rose-50 text-rose-700'
                  }`}
                >
                  Total {totalWeight}%
                </span>
              </div>

              <div className="space-y-3">
                <div className="hidden grid-cols-[1fr_1fr_110px_40px] gap-3 px-1 text-xs font-medium text-slate-500 sm:grid">
                  <span>Nominal minimum (Rp) <span className="text-rose-500">*</span></span>
                  <span>Nominal maksimum (Rp) <span className="text-rose-500">*</span></span>
                  <span>Peluang (%) <span className="text-rose-500">*</span></span>
                  <span />
                </div>
                {form.tiers.map((tier, i) => {
                  const bounds = tierBounds(tier, form.step);
                  return (
                    <div key={i} className="space-y-1">
                      <div className="grid grid-cols-2 gap-3 sm:grid-cols-[1fr_1fr_110px_40px]">
                        <input
                          type="number"
                          min={1}
                          step={form.step || 1}
                          className={input}
                          aria-label={`Nominal minimum rentang ${i + 1}`}
                          value={tier.from}
                          onChange={(e) => setTier(i, 'from', Number(e.target.value))}
                        />
                        <input
                          type="number"
                          min={1}
                          step={form.step || 1}
                          className={input}
                          aria-label={`Nominal maksimum rentang ${i + 1}`}
                          value={tier.to}
                          onChange={(e) => setTier(i, 'to', Number(e.target.value))}
                        />
                        <input
                          type="number"
                          min={0}
                          max={100}
                          className={input}
                          aria-label={`Peluang rentang ${i + 1}`}
                          value={tier.weight}
                          onChange={(e) => setTier(i, 'weight', Number(e.target.value))}
                        />
                        <button
                          type="button"
                          onClick={() => removeTier(i)}
                          disabled={form.tiers.length <= 1}
                          className="inline-flex items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-40"
                          aria-label={`Hapus rentang ${i + 1}`}
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                      <p className={`px-1 text-xs ${bounds ? 'text-slate-500' : 'text-rose-600'}`}>
                        {bounds
                          ? `${tier.weight}% peti berisi ${rupiah(bounds[0])} – ${rupiah(bounds[1])}`
                          : 'Rentang ini tidak memuat kelipatan nominal.'}
                      </p>
                    </div>
                  );
                })}
              </div>

              <button
                type="button"
                onClick={addTier}
                disabled={form.tiers.length >= 10}
                className="inline-flex items-center gap-2 rounded-xl border border-dashed border-slate-300 px-3 py-2 text-sm font-medium text-slate-600 hover:border-emerald-500 hover:text-emerald-700 disabled:opacity-50"
              >
                <Plus className="h-4 w-4" /> Tambah rentang
              </button>
            </section>

            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold text-slate-800">
                <Gift className="h-4 w-4 text-amber-500" /> Ringkasan
              </h2>
              <div className="divide-y divide-slate-100 text-sm">
                <div className="flex items-center justify-between py-2">
                  <span className="text-slate-600">Ditampilkan di aplikasi</span>
                  <span className="font-semibold text-slate-900">
                    {form.is_active && summary.max > 0 ? `Hingga ${rupiah(summary.max)}` : 'Tidak tampil'}
                  </span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-slate-600">Perkiraan rata-rata hadiah per peti (= per iklan)</span>
                  <span className="font-semibold text-slate-900">{rupiah(summary.average)}</span>
                </div>
                <div className="flex items-center justify-between gap-4 py-2">
                  <span className="text-slate-600">
                    Dibanding pendapatan iklan
                    <span className="block text-xs text-slate-400">
                      Pendapatan iklan rewarded di Indonesia kira-kira {rupiah(REVENUE_PER_VIEW[0])}–
                      {rupiah(REVENUE_PER_VIEW[1])} per tayangan; cek laporan AdMob untuk angka sebenarnya.
                    </span>
                  </span>
                  <span className={`shrink-0 text-right font-semibold ${margin.tone}`}>
                    {rupiah(summary.perView)}
                    <span className="block text-xs font-normal">{margin.note}</span>
                  </span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-slate-600">Maksimal rata-rata biaya per customer per hari</span>
                  <span className="font-semibold text-slate-900">{rupiah(summary.perUserDay)}</span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-slate-600">Sudah dibagikan hari ini</span>
                  <span className="font-semibold text-slate-900">
                    {rupiah(form.paid_today ?? 0)}
                    {form.daily_budget > 0 && <span className="font-normal text-slate-500"> / {rupiah(form.daily_budget)}</span>}
                  </span>
                </div>
              </div>
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
