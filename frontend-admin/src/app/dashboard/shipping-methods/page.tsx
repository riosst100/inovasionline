'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../lib/api';
import { useLabels } from '../../../lib/labels';
import { ShippingMethod } from '../../../types';
import { AlertCircle, CalendarClock, CheckCircle2, Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';

const rupiah = (n: number) => (n === 0 ? 'Gratis' : `Rp${n.toLocaleString('id-ID')}`);

type FormState = {
  name: string;
  description: string;
  base_fee: string;
  estimated_delivery_time: string;
  free_shipping_min_amount: string;
  requires_schedule: boolean;
  schedule_days_ahead: string;
  is_enabled: boolean;
};

const emptyForm: FormState = {
  name: '',
  description: '',
  base_fee: '0',
  estimated_delivery_time: '',
  free_shipping_min_amount: '',
  requires_schedule: false,
  schedule_days_ahead: '3',
  is_enabled: true,
};

export default function ShippingMethodsPage() {
  const { get: getLabel } = useLabels();
  const [items, setItems] = useState<ShippingMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [modal, setModal] = useState<{ editing: ShippingMethod | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getShippingMethods());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat metode pengiriman.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const openCreate = () => {
    setForm(emptyForm);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (m: ShippingMethod) => {
    setForm({
      name: m.name,
      description: m.description ?? '',
      base_fee: String(m.base_fee),
      estimated_delivery_time: m.estimated_delivery_time ?? '',
      free_shipping_min_amount: m.free_shipping_min_amount != null ? String(m.free_shipping_min_amount) : '',
      requires_schedule: m.requires_schedule,
      schedule_days_ahead: String(m.schedule_days_ahead ?? 3),
      is_enabled: m.is_enabled,
    });
    setError(null);
    setModal({ editing: m });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const saved = await adminApi.saveShippingMethod(
        {
          name: form.name.trim(),
          description: form.description.trim() || null,
          base_fee: Number(form.base_fee) || 0,
          estimated_delivery_time: form.estimated_delivery_time.trim() || null,
          free_shipping_min_amount: form.free_shipping_min_amount.trim() ? Number(form.free_shipping_min_amount) : null,
          requires_schedule: form.requires_schedule,
          schedule_days_ahead: Number(form.schedule_days_ahead) || 1,
          is_enabled: form.is_enabled,
        },
        editing?.id
      );
      setModal(null);
      setSuccess(
        editing
          ? 'Metode pengiriman berhasil diperbarui.'
          : saved.requires_schedule
            ? `${saved.name} ditambahkan. Jangan lupa atur jadwal pengirimannya.`
            : `${saved.name} berhasil ditambahkan.`
      );
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan metode pengiriman.'));
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (m: ShippingMethod) => {
    setBusyId(m.id);
    setError(null);
    setSuccess(null);
    try {
      const updated = await adminApi.toggleShippingMethod(m.id);
      setItems((prev) => prev.map((x) => (x.id === updated.id ? updated : x)));
      setSuccess(`${updated.name} ${updated.is_enabled ? 'diaktifkan' : 'dinonaktifkan'}.`);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal mengubah status metode pengiriman.');
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (m: ShippingMethod) => {
    if (!confirm(`Hapus metode pengiriman "${m.name}" beserta jadwal & hari liburnya?`)) return;
    setBusyId(m.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteShippingMethod(m.id);
      setSuccess(`${m.name} berhasil dihapus.`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus metode pengiriman.');
    } finally {
      setBusyId(null);
    }
  };

  const activeCount = items.filter((m) => m.is_enabled).length;
  const inputCls =
    'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Metode Pengiriman</h1>
            <p className="text-sm text-slate-500">
              Kelola metode pengiriman yang bisa dipilih pembeli saat checkout, termasuk metode terjadwal seperti jastip.
            </p>
          </div>
          <button
            onClick={openCreate}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" /> Tambah Metode
          </button>
        </div>

        {error && !modal && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}
        {!loading && items.length > 0 && activeCount === 0 && (
          <div className="flex items-center gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
            <AlertCircle className="h-4 w-4 shrink-0" /> Semua metode nonaktif — pembeli tidak dapat melakukan checkout.
          </div>
        )}

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : items.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada metode pengiriman.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Metode</th>
                  <th className="px-4 py-3">Estimasi</th>
                  <th className="px-4 py-3">Ongkir</th>
                  <th className="px-4 py-3">Jadwal</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {items.map((m) => (
                  <tr key={m.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{m.name}</div>
                      <span className={`mt-0.5 inline-block rounded-full px-2 py-0.5 text-[10px] font-bold ${getLabel('shipping_type', m.type).badge}`}>
                        {getLabel('shipping_type', m.type).label}
                      </span>
                      {m.description && <div className="text-xs text-slate-500">{m.description}</div>}
                    </td>
                    <td className="px-4 py-3 text-slate-600">{m.estimated_delivery_time || '-'}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-700">
                      {rupiah(m.base_fee)}
                      {m.free_shipping_min_amount != null && (
                        <div className="text-[11px] text-emerald-600">
                          Gratis ≥ {rupiah(m.free_shipping_min_amount)}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {m.requires_schedule ? (
                        <Link
                          href={`/dashboard/delivery-schedules?method=${m.id}`}
                          className={`inline-flex items-center gap-1 text-xs font-semibold hover:underline ${
                            m.delivery_schedules_count ? 'text-emerald-700' : 'text-amber-700'
                          }`}
                        >
                          <CalendarClock className="h-3.5 w-3.5" />
                          {m.delivery_schedules_count ? `${m.delivery_schedules_count} jadwal` : 'Belum ada jadwal'} · Atur
                        </Link>
                      ) : (
                        <span className="text-xs text-slate-400">Tidak perlu</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        role="switch"
                        aria-checked={m.is_enabled}
                        aria-label={`${m.is_enabled ? 'Nonaktifkan' : 'Aktifkan'} ${m.name}`}
                        onClick={() => toggle(m)}
                        disabled={busyId !== null}
                        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors disabled:opacity-50 ${
                          m.is_enabled ? 'bg-emerald-500' : 'bg-slate-300'
                        }`}
                      >
                        <span
                          className={`inline-block h-5 w-5 rounded-full bg-white shadow transition-transform ${
                            m.is_enabled ? 'translate-x-5' : 'translate-x-0.5'
                          }`}
                        />
                      </button>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(m)}
                        title="Ubah"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => remove(m)}
                        disabled={busyId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {busyId === m.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
          <form
            onSubmit={submit}
            className="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">
                {modal.editing ? 'Ubah Metode Pengiriman' : 'Tambah Metode Pengiriman'}
              </h2>
              <button type="button" onClick={() => setModal(null)} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
                <X className="h-5 w-5" />
              </button>
            </div>

            {error && (
              <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
                <AlertCircle className="h-4 w-4 shrink-0" /> {error}
              </div>
            )}

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Nama Metode <span className="text-rose-500">*</span></label>
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
                maxLength={100}
                placeholder="mis. Jastip Maysa"
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Deskripsi (opsional)</label>
              <input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                maxLength={255}
                placeholder="mis. Titip beli & antar setiap Sabtu"
                className={inputCls}
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Ongkir (Rp) <span className="text-rose-500">*</span></label>
                <input
                  type="number"
                  min={0}
                  step={500}
                  value={form.base_fee}
                  onChange={(e) => setForm({ ...form, base_fee: e.target.value })}
                  required
                  className={inputCls}
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Estimasi Waktu</label>
                <input
                  value={form.estimated_delivery_time}
                  onChange={(e) => setForm({ ...form, estimated_delivery_time: e.target.value })}
                  maxLength={100}
                  placeholder="mis. 15-30 menit"
                  className={inputCls}
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Gratis Ongkir Mulai Belanja (Rp)</label>
              <input
                type="number"
                min={0}
                value={form.free_shipping_min_amount}
                onChange={(e) => setForm({ ...form, free_shipping_min_amount: e.target.value })}
                placeholder="Kosongkan jika tidak ada"
                className={inputCls}
              />
            </div>

            <div className="space-y-3 rounded-xl border border-slate-200 p-3">
              <label className="flex items-start gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  className="mt-0.5"
                  checked={form.requires_schedule}
                  onChange={(e) => setForm({ ...form, requires_schedule: e.target.checked })}
                />
                <span>
                  <span className="font-medium">Pembeli memilih jadwal pengiriman</span>
                  <span className="block text-xs text-slate-500">
                    Hari, jam & hari libur diatur di menu Jadwal Pengiriman.
                  </span>
                </span>
              </label>
              {form.requires_schedule && (
                <div>
                  <label className="mb-1 block text-xs font-medium text-slate-600">Bisa dipesan hingga (hari ke depan) <span className="text-rose-500">*</span></label>
                  <input
                    type="number"
                    min={1}
                    max={60}
                    value={form.schedule_days_ahead}
                    onChange={(e) => setForm({ ...form, schedule_days_ahead: e.target.value })}
                    required
                    className={inputCls}
                  />
                  <p className="mt-1 text-[11px] text-slate-400">1 = hanya hari ini, 7 = hari ini s.d. 6 hari ke depan.</p>
                </div>
              )}
            </div>

            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={form.is_enabled}
                onChange={(e) => setForm({ ...form, is_enabled: e.target.checked })}
              />
              Aktif
            </label>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setModal(null)}
                className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Batal
              </button>
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
        </div>
      )}
    </AdminLayout>
  );
}
