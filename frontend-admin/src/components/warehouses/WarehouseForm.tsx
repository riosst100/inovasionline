'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import dynamic from 'next/dynamic';
import { useRouter } from 'next/navigation';
import { adminApi, ApiError } from '../../lib/api';
import { Warehouse } from '../../types';
import { AlertCircle, Loader2 } from 'lucide-react';

const MapPicker = dynamic(() => import('../ui/MapPicker'), {
  ssr: false,
  loading: () => <div className="h-72 animate-pulse rounded-xl bg-slate-100" />,
});


type FormState = {
  code: string;
  name: string;
  address: string;
  city: string;
  province: string;
  postal_code: string;
  latitude: string;
  longitude: string;
  contact_name: string;
  contact_phone: string;
  notes: string;
  is_active: boolean;
};

const toForm = (w: Warehouse | null): FormState => ({
  code: w?.code ?? '',
  name: w?.name ?? '',
  address: w?.address ?? '',
  city: w?.city ?? '',
  province: w?.province ?? '',
  postal_code: w?.postal_code ?? '',
  latitude: w?.latitude?.toString() ?? '',
  longitude: w?.longitude?.toString() ?? '',
  contact_name: w?.contact_name ?? '',
  contact_phone: w?.contact_phone ?? '',
  notes: w?.notes ?? '',
  is_active: w?.is_active ?? true,
});

const orNull = (s: string) => s.trim() || null;
const numOrNull = (s: string) => (s.trim() === '' ? null : Number(s));

const inputCls =
  'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';
const labelCls = 'mb-1 block text-xs font-medium text-slate-600';

export default function WarehouseForm({ warehouse }: { warehouse: Warehouse | null }) {
  const router = useRouter();
  const [form, setForm] = useState<FormState>(() => toForm(warehouse));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const set = <K extends keyof FormState>(key: K, value: FormState[K]) => setForm((f) => ({ ...f, [key]: value }));

  const lat = form.latitude.trim() === '' || isNaN(Number(form.latitude)) ? null : Number(form.latitude);
  const lng = form.longitude.trim() === '' || isNaN(Number(form.longitude)) ? null : Number(form.longitude);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await adminApi.saveWarehouse(
        {
          code: form.code.trim().toUpperCase(),
          name: form.name.trim(),
          address: orNull(form.address),
          city: orNull(form.city),
          province: orNull(form.province),
          postal_code: orNull(form.postal_code),
          latitude: numOrNull(form.latitude),
          longitude: numOrNull(form.longitude),
          contact_name: orNull(form.contact_name),
          contact_phone: orNull(form.contact_phone),
          notes: orNull(form.notes),
          is_active: form.is_active,
        },
        warehouse?.id
      );
      router.push('/dashboard/warehouses');
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan gudang.'));
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-6">
      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
          <AlertCircle className="h-4 w-4 shrink-0" /> {error}
        </div>
      )}

      <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-sm font-semibold text-slate-900">Informasi Umum</h2>
        <div className="grid gap-3">
          <div>
            <label className={labelCls}>Kode</label>
            <input
              value={form.code}
              onChange={(e) => set('code', e.target.value.toUpperCase())}
              required
              maxLength={30}
              pattern="[A-Z0-9][A-Z0-9_\-]*"
              placeholder="mis. GDG-JKT"
              className={`${inputCls} font-mono`}
            />
          </div>
        </div>
        <div>
          <label className={labelCls}>Nama</label>
          <input
            value={form.name}
            onChange={(e) => set('name', e.target.value)}
            required
            maxLength={120}
            placeholder="mis. Gudang Pusat Jakarta"
            className={inputCls}
          />
        </div>
        <div>
          <label className={labelCls}>Catatan (opsional)</label>
          <input value={form.notes} onChange={(e) => set('notes', e.target.value)} maxLength={255} className={inputCls} />
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input type="checkbox" checked={form.is_active} onChange={(e) => set('is_active', e.target.checked)} />
          Aktif
        </label>
      </section>

      <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-sm font-semibold text-slate-900">Lokasi</h2>
        <div>
          <label className={labelCls}>Alamat</label>
          <input value={form.address} onChange={(e) => set('address', e.target.value)} maxLength={255} className={inputCls} />
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <div>
            <label className={labelCls}>Kota</label>
            <input value={form.city} onChange={(e) => set('city', e.target.value)} maxLength={100} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Provinsi</label>
            <input value={form.province} onChange={(e) => set('province', e.target.value)} maxLength={100} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Kode Pos</label>
            <input value={form.postal_code} onChange={(e) => set('postal_code', e.target.value)} maxLength={10} className={inputCls} />
          </div>
        </div>

        <MapPicker
          latitude={lat}
          longitude={lng}
          onChange={(la, ln) => setForm((f) => ({ ...f, latitude: la.toFixed(7), longitude: ln.toFixed(7) }))}
        />

        <div className="grid gap-3 sm:grid-cols-2">
          <div>
            <label className={labelCls}>Latitude</label>
            <input type="number" step="any" min={-90} max={90} value={form.latitude} onChange={(e) => set('latitude', e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Longitude</label>
            <input type="number" step="any" min={-180} max={180} value={form.longitude} onChange={(e) => set('longitude', e.target.value)} className={inputCls} />
          </div>
        </div>
      </section>

      <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-sm font-semibold text-slate-900">Kontak</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <div>
            <label className={labelCls}>Nama Kontak (PIC)</label>
            <input value={form.contact_name} onChange={(e) => set('contact_name', e.target.value)} maxLength={100} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Telepon Kontak</label>
            <input value={form.contact_phone} onChange={(e) => set('contact_phone', e.target.value)} maxLength={30} className={inputCls} />
          </div>
        </div>
      </section>

      <div className="flex justify-end gap-2">
        <Link
          href="/dashboard/warehouses"
          className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Batal
        </Link>
        <button
          type="submit"
          disabled={saving}
          className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
        >
          {saving && <Loader2 className="h-4 w-4 animate-spin" />}
          Simpan
        </button>
      </div>
    </form>
  );
}
