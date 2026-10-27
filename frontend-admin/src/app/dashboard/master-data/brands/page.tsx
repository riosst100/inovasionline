'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import ImportExportActions from '../../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../../components/data-transfer/DataTransferProgress';
import { adminApi, ApiError } from '../../../../lib/api';
import { useDataTransfers } from '../../../../lib/dataTransfer';
import { Brand, DataTransfer } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Pencil, Plus, Trash2, X } from 'lucide-react';

const IMPORT_HINT = (
  <>
    Kolom: <b>name</b> (wajib), description, is_active (1/0). Brand dengan nama yang sudah ada akan{' '}
    <b>diperbarui</b>; selain itu dibuat baru.
  </>
);

type FormState = {
  name: string;
  description: string;
  is_active: boolean;
};

const emptyForm: FormState = { name: '', description: '', is_active: true };

export default function BrandsPage() {
  const [items, setItems] = useState<Brand[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [modal, setModal] = useState<{ editing: Brand | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getBrands());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat brand.');
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
  const transfers = useDataTransfers({ resource: 'brands', perPage: 5 }, onTransferFinished);

  const openCreate = () => {
    setForm(emptyForm);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (b: Brand) => {
    setForm({ name: b.name, description: b.description ?? '', is_active: b.is_active });
    setError(null);
    setModal({ editing: b });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.saveBrand(
        { name: form.name.trim(), description: form.description.trim() || null, is_active: form.is_active },
        editing?.id
      );
      setModal(null);
      setSuccess(editing ? 'Brand berhasil diperbarui.' : 'Brand berhasil ditambahkan.');
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan brand.'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (b: Brand) => {
    const used = b.products_count ? `\n${b.products_count} produk akan menjadi tanpa brand.` : '';
    if (!confirm(`Hapus brand "${b.name}"?${used}`)) return;
    setDeletingId(b.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteBrand(b.id);
      setSuccess('Brand berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus brand.');
    } finally {
      setDeletingId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const visible = items.filter((b) => !q || b.name.toLowerCase().includes(q));

  const editing = modal?.editing ?? null;

  const inputCls =
    'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-5xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Brand</h1>
            <p className="text-sm text-slate-500">Daftar merek produk. Brand bersifat opsional di setiap produk.</p>
          </div>
          <div className="flex flex-wrap items-start gap-2">
            <ImportExportActions resource="brands" onStarted={transfers.track} importHint={IMPORT_HINT} />
            <button
              onClick={openCreate}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah Brand
            </button>
          </div>
        </div>

        <DataTransferProgress items={transfers.items} resource="brands" />

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
          placeholder="Cari nama brand..."
          className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
        />

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada brand.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Brand</th>
                  <th className="px-4 py-3">Produk</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((b) => (
                  <tr key={b.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{b.name}</div>
                      {b.description && <div className="text-xs text-slate-400">{b.description}</div>}
                    </td>
                    <td className="px-4 py-3 text-slate-600">{b.products_count ?? 0}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          b.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                        }`}
                      >
                        {b.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(b)}
                        title="Ubah"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => remove(b)}
                        disabled={deletingId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {deletingId === b.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
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
              <h2 className="text-lg font-bold text-slate-900">{editing ? 'Ubah Brand' : 'Tambah Brand'}</h2>
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
              <label className="mb-1 block text-xs font-medium text-slate-600">Nama Brand <span className="text-rose-500">*</span></label>
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
                maxLength={100}
                placeholder="mis. Indomie"
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Deskripsi (opsional)</label>
              <input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
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
