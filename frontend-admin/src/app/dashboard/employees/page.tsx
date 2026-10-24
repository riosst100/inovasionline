'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import Stat from '../../../components/finance/Stat';
import { apiRequest, ApiError } from '../../../lib/api';
import { rupiah } from '../../../lib/wallet';
import { Employee, EmployeeList, SalaryType } from '../../../types';
import { AlertCircle, CheckCircle2, IdCard, Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';

const SALARY_TYPES: Record<SalaryType, { label: string; unit: string }> = {
  monthly: { label: 'Per bulan', unit: '/ bulan' },
  per_order: { label: 'Per pesanan', unit: '/ pesanan' },
  per_delivery: { label: 'Per antar', unit: '/ antar' },
};

type FormState = {
  name: string;
  phone: string;
  position: string;
  salary_type: SalaryType;
  salary_amount: string;
  notes: string;
  is_active: boolean;
};

const emptyForm: FormState = { name: '', phone: '', position: '', salary_type: 'monthly', salary_amount: '', notes: '', is_active: true };

const toDigits = (v: string) => v.replace(/\D/g, '');

export default function EmployeesPage() {
  const [data, setData] = useState<EmployeeList | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<SalaryType | ''>('');
  const [modal, setModal] = useState<{ editing: Employee | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setData(await apiRequest<EmployeeList>('/admin/employees'));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat karyawan.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(load, 0);
    return () => clearTimeout(timer);
  }, [load]);

  const openCreate = () => {
    setForm(emptyForm);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (e: Employee) => {
    setForm({
      name: e.name,
      phone: e.phone ?? '',
      position: e.position,
      salary_type: e.salary_type,
      salary_amount: String(Math.round(Number(e.salary_amount))),
      notes: e.notes ?? '',
      is_active: e.is_active,
    });
    setError(null);
    setModal({ editing: e });
  };

  const submit = async (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(editing ? `/admin/employees/${editing.id}` : '/admin/employees', {
        method: editing ? 'PUT' : 'POST',
        body: JSON.stringify({
          name: form.name.trim(),
          phone: form.phone.trim() || null,
          position: form.position.trim(),
          salary_type: form.salary_type,
          salary_amount: Number(form.salary_amount || 0),
          notes: form.notes.trim() || null,
          is_active: form.is_active,
        }),
      });
      setModal(null);
      setSuccess(editing ? 'Karyawan berhasil diperbarui.' : 'Karyawan berhasil ditambahkan.');
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan karyawan.'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (e: Employee) => {
    if (!confirm(`Hapus karyawan "${e.name}"?`)) return;
    setDeletingId(e.id);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(`/admin/employees/${e.id}`, { method: 'DELETE' });
      setSuccess('Karyawan berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus karyawan.');
    } finally {
      setDeletingId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const visible = (data?.items ?? []).filter(
    (e) =>
      (!typeFilter || e.salary_type === typeFilter) &&
      (!q || [e.name, e.position, e.phone].some((v) => v?.toLowerCase().includes(q)))
  );
  const editing = modal?.editing ?? null;

  const inputCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-5xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <IdCard className="h-6 w-6 text-emerald-600" />
              <h1 className="text-2xl font-bold text-slate-900">Karyawan</h1>
            </div>
            <p className="mt-1 text-sm text-slate-500">Daftar karyawan beserta posisi dan sistem gajinya.</p>
          </div>
          <button
            onClick={openCreate}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" /> Tambah Karyawan
          </button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Stat label="Karyawan aktif" value={data ? data.summary.active.toLocaleString('id-ID') : '—'} />
          <Stat
            label="Total gaji bulanan tetap"
            value={data ? rupiah(data.summary.monthly_total) : '—'}
            hint="Karyawan aktif bergaji per bulan; gaji per pesanan/antar tergantung jumlahnya"
          />
        </div>

        {error && !modal && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        <div className="flex flex-wrap gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama, posisi, atau no. HP..."
            className="min-w-[200px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value as SalaryType | '')}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
          >
            <option value="">Semua sistem gaji</option>
            {Object.entries(SALARY_TYPES).map(([v, t]) => (
              <option key={v} value={v}>
                {t.label}
              </option>
            ))}
          </select>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada karyawan.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Karyawan</th>
                  <th className="px-4 py-3">Posisi</th>
                  <th className="px-4 py-3">Sistem Gaji</th>
                  <th className="px-4 py-3 text-right">Jumlah</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((e) => (
                  <tr key={e.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{e.name}</div>
                      {e.phone && <div className="text-xs text-slate-500">{e.phone}</div>}
                      {e.notes && <div className="text-xs text-slate-400">{e.notes}</div>}
                    </td>
                    <td className="px-4 py-3 text-slate-700">{e.position}</td>
                    <td className="px-4 py-3 text-slate-600">{SALARY_TYPES[e.salary_type].label}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <span className="font-semibold text-slate-900">{rupiah(Number(e.salary_amount))}</span>{' '}
                      <span className="text-xs text-slate-400">{SALARY_TYPES[e.salary_type].unit}</span>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          e.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                        }`}
                      >
                        {e.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(e)}
                        title="Ubah"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => remove(e)}
                        disabled={deletingId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {deletingId === e.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
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
          <form onSubmit={submit} className="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">{editing ? 'Ubah Karyawan' : 'Tambah Karyawan'}</h2>
              <button type="button" onClick={() => setModal(null)} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
                <X className="h-5 w-5" />
              </button>
            </div>

            {error && (
              <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
                <AlertCircle className="h-4 w-4 shrink-0" /> {error}
              </div>
            )}

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Nama</label>
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required maxLength={150} className={inputCls} />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">No. HP (opsional)</label>
                <input
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  maxLength={30}
                  inputMode="tel"
                  className={inputCls}
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Posisi</label>
              <input
                value={form.position}
                onChange={(e) => setForm({ ...form, position: e.target.value })}
                required
                maxLength={100}
                list="employee-positions"
                placeholder="mis. Kurir, Admin Gudang, Packer"
                className={inputCls}
              />
              <datalist id="employee-positions">
                {data?.positions.map((p) => <option key={p} value={p} />)}
              </datalist>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Sistem Gaji</label>
              <div className="grid grid-cols-3 gap-2">
                {(Object.entries(SALARY_TYPES) as [SalaryType, { label: string }][]).map(([v, t]) => (
                  <button
                    key={v}
                    type="button"
                    onClick={() => setForm({ ...form, salary_type: v })}
                    className={`rounded-lg border px-3 py-2 text-sm font-medium ${
                      form.salary_type === v ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Jumlah Gaji {SALARY_TYPES[form.salary_type].unit}</label>
              <div className="relative">
                <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
                <input
                  inputMode="numeric"
                  required
                  value={form.salary_amount ? Number(form.salary_amount).toLocaleString('id-ID') : ''}
                  onChange={(e) => setForm({ ...form, salary_amount: toDigits(e.target.value) })}
                  className={`${inputCls} pl-9`}
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Catatan (opsional)</label>
              <input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} maxLength={255} className={inputCls} />
            </div>

            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
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
