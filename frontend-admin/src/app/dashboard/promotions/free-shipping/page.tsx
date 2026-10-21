'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { FreeShippingSettings, PaymentMethodOption, ShippingMethod } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Save } from 'lucide-react';

const DEFAULTS: FreeShippingSettings = {
  is_active: false,
  min_subtotal: null,
  payment_method_ids: [],
  shipping_method_ids: [],
};

type Option = { id: string; name: string; is_enabled: boolean };

function toggle(list: string[], id: string): string[] {
  return list.includes(id) ? list.filter((x) => x !== id) : [...list, id];
}

function Checklist({
  title,
  hint,
  items,
  selected,
  onToggle,
}: {
  title: string;
  hint: string;
  items: Option[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  return (
    <section className="space-y-3 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div>
        <h2 className="text-sm font-semibold text-slate-800">{title}</h2>
        <p className="text-xs text-slate-500">{hint}</p>
      </div>
      {items.length === 0 ? (
        <p className="text-sm text-slate-400">Belum ada data.</p>
      ) : (
        <div className="grid gap-2 sm:grid-cols-2">
          {items.map((item) => (
            <label
              key={item.id}
              className="flex cursor-pointer items-center gap-3 rounded-xl border border-slate-200 px-3 py-2 text-sm hover:bg-slate-50"
            >
              <input
                type="checkbox"
                className="h-4 w-4"
                checked={selected.includes(item.id)}
                onChange={() => onToggle(item.id)}
              />
              <span className="flex-1 text-slate-800">{item.name}</span>
              {!item.is_enabled && (
                <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-medium text-slate-500">
                  Nonaktif
                </span>
              )}
            </label>
          ))}
        </div>
      )}
    </section>
  );
}

export default function FreeShippingPage() {
  const [form, setForm] = useState<FreeShippingSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [payments, setPayments] = useState<PaymentMethodOption[]>([]);
  const [shippings, setShippings] = useState<ShippingMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const [settings, paymentList, shippingList] = await Promise.all([
          adminApi.getFreeShipping(),
          adminApi.getPaymentMethodOptions(),
          adminApi.getShippingMethods(),
        ]);
        setForm(settings);
        setInitial(JSON.stringify(settings));
        setPayments(paymentList);
        setShippings(shippingList);
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan gratis ongkir.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const update = (next: Partial<FreeShippingSettings>) => {
    setSuccess(null);
    setForm((f) => ({ ...f, ...next }));
  };

  const dirty = JSON.stringify(form) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const res = await adminApi.saveFreeShipping(form);
      setForm(res);
      setInitial(JSON.stringify(res));
      setSuccess('Gratis ongkir berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan gratis ongkir.'
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
            <h1 className="text-2xl font-bold text-slate-900">Gratis Ongkir</h1>
            <p className="text-sm text-slate-500">
              Ongkir menjadi Rp0 jika pesanan memakai salah satu metode pembayaran dan salah satu metode pengiriman
              yang dipilih di bawah.
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
                  <p className="text-sm font-semibold text-slate-800">Aktifkan gratis ongkir</p>
                  <p className="text-xs text-slate-500">Jika nonaktif, ongkir dihitung normal.</p>
                </div>
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={form.is_active}
                  onChange={(e) => update({ is_active: e.target.checked })}
                />
              </label>

              <div className="sm:w-1/2">
                <label className="mb-1 block text-sm font-medium text-slate-700">Minimal belanja (Rp)</label>
                <input
                  type="number"
                  min={0}
                  step={1000}
                  placeholder="Tanpa minimal"
                  className={input}
                  value={form.min_subtotal ?? ''}
                  onChange={(e) => update({ min_subtotal: e.target.value === '' ? null : Number(e.target.value) })}
                />
                <p className="mt-1 text-xs text-slate-500">Kosongkan jika gratis ongkir berlaku untuk semua nominal.</p>
              </div>
            </section>

            <Checklist
              title="Metode pembayaran"
              hint="Gratis ongkir hanya berlaku jika customer membayar dengan salah satu metode ini."
              items={payments}
              selected={form.payment_method_ids}
              onToggle={(id) => update({ payment_method_ids: toggle(form.payment_method_ids, id) })}
            />

            <Checklist
              title="Metode pengiriman"
              hint="Gratis ongkir hanya berlaku jika customer memilih salah satu pengiriman ini."
              items={shippings}
              selected={form.shipping_method_ids}
              onToggle={(id) => update({ shipping_method_ids: toggle(form.shipping_method_ids, id) })}
            />
          </>
        )}
      </div>
    </AdminLayout>
  );
}
