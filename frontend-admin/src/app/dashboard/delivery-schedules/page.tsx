'use client';

import React, { Suspense, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../lib/api';
import { DeliveryHoliday, DeliverySchedule, ShippingMethod } from '../../../types';
import { AlertCircle, CalendarOff, CheckCircle2, Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';

/** ISO weekday → label (1 = Senin). */
const DAYS: { value: number; label: string }[] = [
  { value: 1, label: 'Sen' },
  { value: 2, label: 'Sel' },
  { value: 3, label: 'Rab' },
  { value: 4, label: 'Kam' },
  { value: 5, label: 'Jum' },
  { value: 6, label: 'Sab' },
  { value: 7, label: 'Min' },
];

type FormState = {
  label: string;
  start_time: string;
  end_time: string;
  cutoff_minutes: string;
  quota: string;
  days: number[];
  is_active: boolean;
};

const emptyForm: FormState = {
  label: '',
  start_time: '09:00',
  end_time: '12:00',
  cutoff_minutes: '60',
  quota: '',
  days: DAYS.map((d) => d.value),
  is_active: true,
};

const daysText = (days: number[] | null) =>
  !days || days.length === 0 || days.length === 7
    ? 'Setiap hari'
    : days.map((d) => DAYS.find((x) => x.value === d)?.label).join(', ');

const cutoffText = (minutes: number) => {
  if (minutes <= 0) return 'Sampai jam mulai';
  if (minutes % 1440 === 0) return `${minutes / 1440} hari sebelum`;
  if (minutes % 60 === 0) return `${minutes / 60} jam sebelum`;
  return `${minutes} menit sebelum`;
};

const formatDate = (ymd: string) =>
  new Date(`${ymd}T00:00:00`).toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

const errorText = (err: unknown, fallback: string) => {
  const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
  return first || (err instanceof ApiError ? err.message : fallback);
};

const inputCls =
  'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

export default function DeliverySchedulesPage() {
  return (
    <AdminLayout>
      <Suspense>
        <DeliverySchedulesContent />
      </Suspense>
    </AdminLayout>
  );
}

function DeliverySchedulesContent() {
  const router = useRouter();
  const params = useSearchParams();
  const [methods, setMethods] = useState<ShippingMethod[] | null>(null);
  const [methodId, setMethodId] = useState<string>(params.get('method') ?? '');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    adminApi
      .getShippingMethods()
      .then((all) => {
        const scheduled = all.filter((m) => m.requires_schedule);
        setMethods(scheduled);
        setMethodId((current) => (scheduled.some((m) => m.id === current) ? current : (scheduled[0]?.id ?? '')));
      })
      .catch((e) => {
        setMethods([]);
        setError(errorText(e, 'Gagal memuat metode pengiriman.'));
      });
  }, []);

  const selectMethod = (id: string) => {
    setMethodId(id);
    router.replace(`/dashboard/delivery-schedules?method=${id}`);
  };

  const method = methods?.find((m) => m.id === methodId) ?? null;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Jadwal Pengiriman</h1>
          <p className="text-sm text-slate-500">
            Atur hari & jam pengiriman serta hari libur untuk metode pengiriman terjadwal. Jam dalam WIB.
          </p>
        </div>
        {methods && methods.length > 0 && (
          <select
            value={methodId}
            onChange={(e) => selectMethod(e.target.value)}
            aria-label="Metode pengiriman"
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-medium"
          >
            {methods.map((m) => (
              <option key={m.id} value={m.id}>
                {m.name}
                {m.is_enabled ? '' : ' (nonaktif)'}
              </option>
            ))}
          </select>
        )}
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
          <AlertCircle className="h-4 w-4 shrink-0" /> {error}
        </div>
      )}

      {methods === null ? (
        <div className="flex justify-center p-10">
          <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
        </div>
      ) : !method ? (
        <div className="rounded-2xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">
          Belum ada metode pengiriman terjadwal. Tambahkan atau ubah metode di{' '}
          <Link href="/dashboard/shipping-methods" className="font-semibold text-emerald-600 hover:underline">
            Metode Pengiriman
          </Link>{' '}
          dan centang &quot;Pembeli memilih jadwal pengiriman&quot;.
        </div>
      ) : (
        <>
          <p className="text-xs text-slate-500">
            Pembeli {method.name} bisa memesan untuk hari ini hingga {method.schedule_days_ahead - 1} hari ke depan.{' '}
            <Link href="/dashboard/shipping-methods" className="font-medium text-emerald-600 hover:underline">
              Ubah
            </Link>
          </p>
          <SchedulesSection key={`s-${method.id}`} method={method} />
          <HolidaysSection key={`h-${method.id}`} method={method} />
        </>
      )}
    </div>
  );
}

function SchedulesSection({ method }: { method: ShippingMethod }) {
  const [items, setItems] = useState<DeliverySchedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [modal, setModal] = useState<{ editing: DeliverySchedule | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getDeliverySchedules(method.id));
    } catch (e) {
      setError(errorText(e, 'Gagal memuat jadwal pengiriman.'));
    } finally {
      setLoading(false);
    }
  }, [method.id]);

  useEffect(() => {
    load();
  }, [load]);

  const openCreate = () => {
    setForm(emptyForm);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (s: DeliverySchedule) => {
    setForm({
      label: s.label,
      start_time: s.start_time,
      end_time: s.end_time,
      cutoff_minutes: String(s.cutoff_minutes),
      quota: s.quota != null ? String(s.quota) : '',
      days: s.days ?? DAYS.map((d) => d.value),
      is_active: s.is_active,
    });
    setError(null);
    setModal({ editing: s });
  };

  const toggleDay = (day: number) =>
    setForm({
      ...form,
      days: form.days.includes(day) ? form.days.filter((d) => d !== day) : [...form.days, day].sort(),
    });

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    if (form.days.length === 0) {
      setError('Pilih minimal satu hari.');
      return;
    }
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.saveDeliverySchedule(
        {
          shipping_method_id: method.id,
          label: form.label.trim(),
          start_time: form.start_time,
          end_time: form.end_time,
          cutoff_minutes: Number(form.cutoff_minutes) || 0,
          quota: form.quota.trim() ? Number(form.quota) : null,
          days: form.days,
          is_active: form.is_active,
        },
        editing?.id
      );
      setModal(null);
      setSuccess(editing ? 'Jadwal berhasil diperbarui.' : 'Jadwal berhasil ditambahkan.');
      await load();
    } catch (err) {
      setError(errorText(err, 'Gagal menyimpan jadwal.'));
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (s: DeliverySchedule) => {
    setBusyId(s.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.saveDeliverySchedule({ ...s, is_active: !s.is_active }, s.id);
      await load();
    } catch (err) {
      setError(errorText(err, 'Gagal mengubah status jadwal.'));
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (s: DeliverySchedule) => {
    if (!confirm(`Hapus jadwal "${s.label} (${s.start_time} - ${s.end_time})"?`)) return;
    setBusyId(s.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteDeliverySchedule(s.id);
      setSuccess('Jadwal berhasil dihapus.');
      await load();
    } catch (err) {
      setError(errorText(err, 'Gagal menghapus jadwal.'));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <section className="space-y-3">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-base font-bold text-slate-900">Hari & Jam Pengiriman</h2>
        <button
          onClick={openCreate}
          className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
        >
          <Plus className="h-4 w-4" /> Tambah Jadwal
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

      <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : items.length === 0 ? (
          <p className="p-8 text-center text-sm text-slate-500">
            Belum ada jadwal. Pembeli tidak dapat memilih {method.name} sampai ada jadwal aktif.
          </p>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">Hari</th>
                <th className="px-4 py-3">Jam</th>
                <th className="px-4 py-3">Nama</th>
                <th className="px-4 py-3">Batas Pesan</th>
                <th className="px-4 py-3">Kuota/Hari</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {items.map((s) => (
                <tr key={s.id}>
                  <td className="px-4 py-3 text-slate-700">{daysText(s.days)}</td>
                  <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-slate-700">
                    {s.start_time} - {s.end_time}
                  </td>
                  <td className="px-4 py-3 font-medium text-slate-900">{s.label}</td>
                  <td className="px-4 py-3 text-slate-600">{cutoffText(s.cutoff_minutes)}</td>
                  <td className="px-4 py-3 text-slate-600">{s.quota ?? 'Tanpa batas'}</td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => toggleActive(s)}
                      disabled={busyId !== null}
                      title="Klik untuk mengubah status"
                      className={`rounded-full px-2 py-0.5 text-[11px] font-semibold disabled:opacity-50 ${
                        s.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                      }`}
                    >
                      {s.is_active ? 'Aktif' : 'Nonaktif'}
                    </button>
                  </td>
                  <td className="whitespace-nowrap px-4 py-3 text-right">
                    <button
                      onClick={() => openEdit(s)}
                      title="Ubah"
                      className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                    >
                      <Pencil className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => remove(s)}
                      disabled={busyId !== null}
                      title="Hapus"
                      className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                    >
                      {busyId === s.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
          <form
            onSubmit={submit}
            className="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">
                {modal.editing ? 'Ubah Jadwal' : 'Tambah Jadwal'} · {method.name}
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
              <label className="mb-1 block text-xs font-medium text-slate-600">Hari Pengiriman</label>
              <div className="flex flex-wrap gap-1.5">
                {DAYS.map((d) => {
                  const on = form.days.includes(d.value);
                  return (
                    <button
                      key={d.value}
                      type="button"
                      onClick={() => toggleDay(d.value)}
                      aria-pressed={on}
                      className={`rounded-lg border px-3 py-1.5 text-xs font-semibold ${
                        on
                          ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                          : 'border-slate-200 text-slate-500 hover:bg-slate-50'
                      }`}
                    >
                      {d.label}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Jam Mulai (WIB)</label>
                <input
                  type="time"
                  value={form.start_time}
                  onChange={(e) => setForm({ ...form, start_time: e.target.value })}
                  required
                  className={inputCls}
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Jam Selesai (WIB)</label>
                <input
                  type="time"
                  value={form.end_time}
                  onChange={(e) => setForm({ ...form, end_time: e.target.value })}
                  required
                  className={inputCls}
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Nama Jadwal</label>
              <input
                value={form.label}
                onChange={(e) => setForm({ ...form, label: e.target.value })}
                required
                maxLength={100}
                placeholder="mis. Pagi"
                className={inputCls}
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Batas Pesan (menit)</label>
                <input
                  type="number"
                  min={0}
                  max={10080}
                  value={form.cutoff_minutes}
                  onChange={(e) => setForm({ ...form, cutoff_minutes: e.target.value })}
                  required
                  className={inputCls}
                />
                <p className="mt-1 text-[11px] text-slate-400">
                  Ditutup sekian menit sebelum jam mulai (1440 = 1 hari).
                </p>
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Kuota per Hari</label>
                <input
                  type="number"
                  min={1}
                  value={form.quota}
                  onChange={(e) => setForm({ ...form, quota: e.target.value })}
                  placeholder="Tanpa batas"
                  className={inputCls}
                />
                <p className="mt-1 text-[11px] text-slate-400">Kosongkan jika tidak dibatasi.</p>
              </div>
            </div>

            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
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
    </section>
  );
}

function HolidaysSection({ method }: { method: ShippingMethod }) {
  const [items, setItems] = useState<DeliveryHoliday[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [date, setDate] = useState('');
  const [name, setName] = useState('');
  const [allMethods, setAllMethods] = useState(false);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getDeliveryHolidays(method.id));
    } catch (e) {
      setError(errorText(e, 'Gagal memuat hari libur.'));
    } finally {
      setLoading(false);
    }
  }, [method.id]);

  useEffect(() => {
    load();
  }, [load]);

  const add = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await adminApi.saveDeliveryHoliday({
        date,
        name: name.trim(),
        shipping_method_id: allMethods ? null : method.id,
      });
      setDate('');
      setName('');
      await load();
    } catch (err) {
      setError(errorText(err, 'Gagal menambah hari libur.'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (h: DeliveryHoliday) => {
    const scope = h.shipping_method_id ? method.name : 'semua metode pengiriman';
    if (!confirm(`Hapus hari libur "${h.name}" (${formatDate(h.date)}) untuk ${scope}?`)) return;
    setBusyId(h.id);
    setError(null);
    try {
      await adminApi.deleteDeliveryHoliday(h.id);
      await load();
    } catch (err) {
      setError(errorText(err, 'Gagal menghapus hari libur.'));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <section className="space-y-3">
      <div>
        <h2 className="text-base font-bold text-slate-900">Hari Libur</h2>
        <p className="text-xs text-slate-500">Pada tanggal libur, semua jadwal {method.name} ditutup.</p>
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
          <AlertCircle className="h-4 w-4 shrink-0" /> {error}
        </div>
      )}

      <form
        onSubmit={add}
        className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
      >
        <div className="w-44">
          <label className="mb-1 block text-xs font-medium text-slate-600">Tanggal</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required className={inputCls} />
        </div>
        <div className="min-w-[180px] flex-1">
          <label className="mb-1 block text-xs font-medium text-slate-600">Keterangan</label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            maxLength={100}
            placeholder="mis. Idul Fitri"
            className={inputCls}
          />
        </div>
        <label className="flex items-center gap-2 pb-2 text-sm text-slate-700">
          <input type="checkbox" checked={allMethods} onChange={(e) => setAllMethods(e.target.checked)} />
          Berlaku untuk semua metode
        </label>
        <button
          type="submit"
          disabled={saving}
          className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
        >
          {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />} Tambah Libur
        </button>
      </form>

      <div className="rounded-2xl border border-slate-200 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-8">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : items.length === 0 ? (
          <p className="p-6 text-center text-sm text-slate-500">Tidak ada hari libur mendatang.</p>
        ) : (
          <ul className="divide-y divide-slate-100">
            {items.map((h) => (
              <li key={h.id} className="flex items-center gap-3 px-4 py-3 text-sm">
                <CalendarOff className="h-4 w-4 shrink-0 text-rose-500" />
                <div className="min-w-0 flex-1">
                  <div className="font-medium text-slate-900">{formatDate(h.date)}</div>
                  <div className="text-xs text-slate-500">{h.name}</div>
                </div>
                <span
                  className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                    h.shipping_method_id ? 'bg-slate-100 text-slate-600' : 'bg-amber-100 text-amber-700'
                  }`}
                >
                  {h.shipping_method_id ? method.name : 'Semua metode'}
                </span>
                <button
                  onClick={() => remove(h)}
                  disabled={busyId !== null}
                  title="Hapus"
                  className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                >
                  {busyId === h.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}
