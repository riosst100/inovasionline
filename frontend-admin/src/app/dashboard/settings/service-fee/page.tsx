'use client';

import React, { useEffect, useMemo, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { ServiceFeeSettings } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Save } from 'lucide-react';

const rupiah = (n: number) => 'Rp' + Math.round(n).toLocaleString('id-ID');

const DEFAULTS: ServiceFeeSettings = {
  is_active: false,
  label: 'Biaya Layanan',
  type: 'fixed',
  value: 0,
  min_fee: null,
  max_fee: null,
};

const toNum = (v: string): number | null => (v.trim() === '' ? null : Number(v));

function calculate(s: ServiceFeeSettings, subtotal: number): number {
  if (!s.is_active || !(s.value > 0)) return 0;
  let fee = s.type === 'percent' ? (subtotal * s.value) / 100 : s.value;
  if (s.min_fee != null) fee = Math.max(fee, s.min_fee);
  if (s.max_fee != null) fee = Math.min(fee, s.max_fee);
  return Math.round(fee);
}

export default function ServiceFeePage() {
  const [form, setForm] = useState<ServiceFeeSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await adminApi.getServiceFee();
        setForm(res);
        setInitial(JSON.stringify(res));
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan biaya layanan.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const set = <K extends keyof ServiceFeeSettings>(key: K, value: ServiceFeeSettings[K]) => {
    setSuccess(null);
    setForm((f) => ({ ...f, [key]: value }));
  };

  const dirty = JSON.stringify(form) !== initial;
  const examples = useMemo(() => [20000, 100000, 500000], []);

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const res = await adminApi.saveServiceFee(form);
      setForm(res);
      setInitial(JSON.stringify(res));
      setSuccess('Biaya layanan berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan biaya layanan.'
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
            <h1 className="text-2xl font-bold text-slate-900">Biaya Layanan</h1>
            <p className="text-sm text-slate-500">
              Biaya yang ditambahkan ke total pesanan saat checkout. Berlaku untuk pesanan baru; pesanan yang sudah
              dibuat tidak berubah.
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
                  <p className="text-sm font-semibold text-slate-800">Aktifkan biaya layanan</p>
                  <p className="text-xs text-slate-500">Jika nonaktif, biaya layanan tampil &quot;GRATIS&quot; di checkout.</p>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => set('is_active', e.target.checked)}
                />
              </label>

              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">Nama yang ditampilkan <span className="text-rose-500">*</span></label>
                <input
                  className={input}
                  maxLength={60}
                  value={form.label}
                  onChange={(e) => set('label', e.target.value)}
                />
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">Jenis biaya <span className="text-rose-500">*</span></label>
                  <select
                    className={input}
                    value={form.type}
                    onChange={(e) => set('type', e.target.value as 'fixed' | 'percent')}
                  >
                    <option value="fixed">Nominal tetap (Rp)</option>
                    <option value="percent">Persentase dari subtotal produk (%)</option>
                  </select>
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-slate-700">
                    {form.type === 'percent' ? 'Persentase (%)' : 'Nominal (Rp)'} <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={form.type === 'percent' ? 100 : undefined}
                    step={form.type === 'percent' ? 0.1 : 100}
                    className={input}
                    value={form.value}
                    onChange={(e) => set('value', Number(e.target.value))}
                  />
                </div>
              </div>

              {(
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label className="mb-1 block text-sm font-medium text-slate-700">Biaya minimum (Rp, opsional)</label>
                    <input
                      type="number"
                      min={0}
                      className={input}
                      value={form.min_fee ?? ''}
                      onChange={(e) => set('min_fee', toNum(e.target.value))}
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-sm font-medium text-slate-700">Biaya maksimum (Rp, opsional)</label>
                    <input
                      type="number"
                      min={0}
                      className={input}
                      value={form.max_fee ?? ''}
                      onChange={(e) => set('max_fee', toNum(e.target.value))}
                    />
                  </div>
                </div>
              )}
            </section>

            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="mb-3 text-sm font-semibold text-slate-800">Simulasi</h2>
              <div className="divide-y divide-slate-100 text-sm">
                {examples.map((s) => (
                  <div key={s} className="flex items-center justify-between py-2">
                    <span className="text-slate-600">Subtotal produk {rupiah(s)}</span>
                    <span className="font-semibold text-slate-900">
                      {form.label || 'Biaya Layanan'}: {calculate(form, s) > 0 ? rupiah(calculate(form, s)) : 'GRATIS'}
                    </span>
                  </div>
                ))}
              </div>
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
