'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import ImportExportActions from '../../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../../components/data-transfer/DataTransferProgress';
import { adminApi, ApiError } from '../../../../lib/api';
import { useDataTransfers } from '../../../../lib/dataTransfer';
import { DataTransfer, Supplier } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';

const IMPORT_HINT = (
  <>
    Kolom: <b>name</b> (wajib untuk supplier baru), id, contact_name, phone, email, address, notes, is_active (1/0).
    Baris dengan id yang sudah ada, atau nama yang sama, akan <b>diperbarui</b>; selain itu dibuat baru.
  </>
);

type FormState = {
  name: string;
  contact_name: string;
  phone: string;
  email: string;
  address: string;
  notes: string;
  is_active: boolean;
};

const emptyForm: FormState = {
  name: '',
  contact_name: '',
  phone: '',
  email: '',
  address: '',
  notes: '',
  is_active: true,
};

export default function SuppliersPage() {
  const [items, setItems] = useState<Supplier[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [modal, setModal] = useState<{ editing: Supplier | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getSuppliers());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat supplier.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(load, 0);
    return () => clearTimeout(timer);
  }, [load]);

  const onTransferFinished = useCallback(
    (t: DataTransfer) => {
      if (t.type === 'import' && t.status === 'completed') load();
    },
    [load]
  );
  const transfers = useDataTransfers({ resource: 'suppliers', perPage: 5 }, onTransferFinished);

  const openCreate = () => {
    setForm(emptyForm);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (s: Supplier) => {
    setForm({
      name: s.name,
      contact_name: s.contact_name ?? '',
      phone: s.phone ?? '',
      email: s.email ?? '',
      address: s.address ?? '',
      notes: s.notes ?? '',
      is_active: s.is_active,
    });
    setError(null);
    setModal({ editing: s });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const orNull = (v: string) => v.trim() || null;
      await adminApi.saveSupplier(
        {
          name: form.name.trim(),
          contact_name: orNull(form.contact_name),
          phone: orNull(form.phone),
          email: orNull(form.email),
          address: orNull(form.address),
          notes: orNull(form.notes),
          is_active: form.is_active,
        },
        editing?.id
      );
      setModal(null);
      setSuccess(editing ? 'Supplier berhasil diperbarui.' : 'Supplier berhasil ditambahkan.');
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan supplier.'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (s: Supplier) => {
    const used = s.products_count ? `\n${s.products_count} produk akan menjadi tanpa supplier.` : '';
    if (!confirm(`Hapus supplier "${s.name}"?${used}`)) return;
    setDeletingId(s.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteSupplier(s.id);
      setSuccess('Supplier berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus supplier.');
    } finally {
      setDeletingId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const visible = items.filter(
    (s) =>
      !q ||
      [s.name, s.contact_name, s.phone, s.email].some((v) => v?.toLowerCase().includes(q))
  );

  const editing = modal?.editing ?? null;

  const inputCls =
    'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-5xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Supplier</h1>
            <p className="text-sm text-slate-500">Daftar pemasok barang. Supplier dapat dipilih di setiap produk.</p>
          </div>
          <div className="flex flex-wrap items-start gap-2">
            <ImportExportActions resource="suppliers" onStarted={transfers.track} importHint={IMPORT_HINT} />
            <button
              onClick={openCreate}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah Supplier
            </button>
          </div>
        </div>

        <DataTransferProgress items={transfers.items} resource="suppliers" />

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

        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Cari nama, kontak, telepon, atau email..."
          className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
        />

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada supplier.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Supplier</th>
                  <th className="px-4 py-3">Kontak</th>
                  <th className="px-4 py-3">Produk</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((s) => (
                  <tr key={s.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{s.name}</div>
                      {s.address && <div className="text-xs text-slate-500">{s.address}</div>}
                      {s.notes && <div className="text-xs text-slate-400">{s.notes}</div>}
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      {s.contact_name && <div>{s.contact_name}</div>}
                      {s.phone && <div className="text-xs">{s.phone}</div>}
                      {s.email && <div className="text-xs">{s.email}</div>}
                      {!s.contact_name && !s.phone && !s.email && '-'}
                    </td>
                    <td className="px-4 py-3 text-slate-600">{s.products_count ?? 0}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          s.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                        }`}
                      >
                        {s.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
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
                        disabled={deletingId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {deletingId === s.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
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
              <h2 className="text-lg font-bold text-slate-900">{editing ? 'Ubah Supplier' : 'Tambah Supplier'}</h2>
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
              <label className="mb-1 block text-xs font-medium text-slate-600">Nama Supplier <span className="text-rose-500">*</span></label>
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
                maxLength={150}
                placeholder="mis. PT Sumber Makmur"
                className={inputCls}
              />
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Nama Kontak (opsional)</label>
                <input
                  value={form.contact_name}
                  onChange={(e) => setForm({ ...form, contact_name: e.target.value })}
                  maxLength={100}
                  className={inputCls}
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Telepon (opsional)</label>
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
              <label className="mb-1 block text-xs font-medium text-slate-600">Email (opsional)</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                maxLength={150}
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Alamat (opsional)</label>
              <input
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                maxLength={255}
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Catatan (opsional)</label>
              <input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                maxLength={255}
                className={inputCls}
              />
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
