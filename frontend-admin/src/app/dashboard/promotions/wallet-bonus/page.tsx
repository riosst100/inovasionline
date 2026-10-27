'use client';

import React, { useEffect, useMemo, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { WalletBonusSettings, WalletBonusTier } from '../../../../types';
import { AlertCircle, CheckCircle2, Gift, Loader2, Plus, Save, Trash2 } from 'lucide-react';

const rupiah = (n: number) => 'Rp' + Math.round(n).toLocaleString('id-ID');

const DEFAULTS: WalletBonusSettings = {
  is_active: true,
  step: 500,
  tiers: [
    { from: 1000, to: 5000, weight: 75 },
    { from: 5500, to: 9500, weight: 20 },
    { from: 10000, to: 20000, weight: 5 },
  ],
};

/** Smallest and largest multiple of step inside the tier, or null if none fits. */
function tierBounds(t: WalletBonusTier, step: number): [number, number] | null {
  if (!(step > 0)) return null;
  const first = Math.ceil(t.from / step) * step;
  const last = Math.floor(t.to / step) * step;
  return first <= last ? [first, last] : null;
}

export default function WalletBonusPage() {
  const [form, setForm] = useState<WalletBonusSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await adminApi.getWalletBonus();
        setForm(res);
        setInitial(JSON.stringify(res));
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan bonus saldo belanja.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const update = (next: Partial<WalletBonusSettings>) => {
    setSuccess(null);
    setForm((f) => ({ ...f, ...next }));
  };

  const setTier = (index: number, key: keyof WalletBonusTier, value: number) =>
    update({ tiers: form.tiers.map((t, i) => (i === index ? { ...t, [key]: value } : t)) });

  const addTier = () => {
    const last = form.tiers[form.tiers.length - 1];
    const from = last ? last.to + form.step : 1000;
    update({ tiers: [...form.tiers, { from, to: from + 5000, weight: 0 }] });
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
    return { max, average };
  }, [form]);

  const dirty = JSON.stringify(form) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const res = await adminApi.saveWalletBonus(form);
      setForm(res);
      setInitial(JSON.stringify(res));
      setSuccess('Bonus saldo belanja berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan bonus saldo belanja.'
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
            <h1 className="text-2xl font-bold text-slate-900">Bonus Saldo Belanja</h1>
            <p className="text-sm text-slate-500">
              Hadiah saldo belanja yang bisa diklaim sekali oleh setiap customer dari halaman utama aplikasi.
              Nominalnya diacak sesuai rentang dan persentase di bawah.
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
                  <p className="text-sm font-semibold text-slate-800">Aktifkan bonus saldo belanja</p>
                  <p className="text-xs text-slate-500">
                    Jika nonaktif, banner &quot;Hadiah Saldo Belanja&quot; tidak tampil dan bonus tidak bisa diklaim.
                  </p>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => update({ is_active: e.target.checked })}
                />
              </label>

              <div className="sm:w-1/2">
                <label className="mb-1 block text-sm font-medium text-slate-700">Kelipatan nominal (Rp) <span className="text-rose-500">*</span></label>
                <input
                  type="number"
                  min={1}
                  step={100}
                  className={input}
                  value={form.step}
                  onChange={(e) => update({ step: Number(e.target.value) })}
                />
                <p className="mt-1 text-xs text-slate-500">
                  Contoh kelipatan {rupiah(500)}: bonus bisa {rupiah(1000)}, {rupiah(1500)}, {rupiah(2000)}, dst.
                </p>
              </div>
            </section>

            <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <h2 className="text-sm font-semibold text-slate-800">Rentang nominal &amp; peluang</h2>
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
                          ? `${tier.weight}% customer mendapat ${rupiah(bounds[0])} – ${rupiah(bounds[1])}`
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
                  <span className="text-slate-600">Perkiraan rata-rata biaya per customer</span>
                  <span className="font-semibold text-slate-900">{rupiah(summary.average)}</span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-slate-600">Perkiraan biaya untuk 1.000 customer</span>
                  <span className="font-semibold text-slate-900">{rupiah(summary.average * 1000)}</span>
                </div>
              </div>
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
