'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import ImportExportActions from '../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../components/data-transfer/DataTransferProgress';
import { adminApi, ApiError } from '../../../lib/api';
import { useDataTransfers } from '../../../lib/dataTransfer';
import { DataTransfer, ProductAttribute, ProductAttributeType } from '../../../types';
import { AlertCircle, CheckCircle2, Loader2, Lock, Pencil, Plus, Trash2, X } from 'lucide-react';

const TYPE_LABELS: Record<ProductAttributeType, string> = {
  text: 'Teks',
  textarea: 'Teks Panjang',
  number: 'Angka',
  boolean: 'Ya / Tidak',
  select: 'Pilihan',
  date: 'Tanggal',
};

const IMPORT_HINT = (
  <>
    Kolom: <b>code</b> (wajib), <b>name</b> (wajib), <b>type</b> (wajib untuk atribut kustom: text, textarea,
    number, boolean, select, date), options (untuk select, pisahkan dengan |), description, is_required (1/0),
    is_active (1/0), sort_order. Atribut dengan code yang sudah ada akan <b>diperbarui</b>; selain itu dibuat baru.
    Atribut sistem hanya memperbarui name, description, dan is_active.
  </>
);

type FormState = {
  code: string;
  name: string;
  type: ProductAttributeType;
  optionsText: string;
  description: string;
  is_required: boolean;
  is_active: boolean;
};

const emptyForm: FormState = {
  code: '',
  name: '',
  type: 'text',
  optionsText: '',
  description: '',
  is_required: false,
  is_active: true,
};

const slugCode = (s: string) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/^[0-9]+/, '');

export default function ProductAttributesPage() {
  const [items, setItems] = useState<ProductAttribute[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [filter, setFilter] = useState<'all' | 'system' | 'custom'>('all');
  const [search, setSearch] = useState('');
  const [modal, setModal] = useState<{ editing: ProductAttribute | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [codeTouched, setCodeTouched] = useState(false);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getProductAttributes());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat atribut produk.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const onTransferFinished = useCallback(
    (t: DataTransfer) => {
      if (t.type === 'import' && t.status === 'completed') load();
    },
    [load]
  );
  const transfers = useDataTransfers({ resource: 'attributes', perPage: 5 }, onTransferFinished);

  const openCreate = () => {
    setForm(emptyForm);
    setCodeTouched(false);
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (a: ProductAttribute) => {
    setForm({
      code: a.code,
      name: a.name,
      type: a.type,
      optionsText: (a.options ?? []).join('\n'),
      description: a.description ?? '',
      is_required: a.is_required,
      is_active: a.is_active,
    });
    setError(null);
    setModal({ editing: a });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const payload: Record<string, unknown> = {
        name: form.name.trim(),
        description: form.description.trim() || null,
        is_active: form.is_active,
      };
      if (!editing?.is_system) {
        payload.type = form.type;
        payload.is_required = form.is_required;
        payload.options =
          form.type === 'select'
            ? form.optionsText.split('\n').map((o) => o.trim()).filter(Boolean)
            : null;
      }
      if (!editing) payload.code = form.code.trim();

      await adminApi.saveProductAttribute(payload as Partial<ProductAttribute>, editing?.id);
      setModal(null);
      setSuccess(editing ? 'Atribut berhasil diperbarui.' : 'Atribut berhasil ditambahkan.');
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan atribut.'));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (a: ProductAttribute) => {
    if (!confirm(`Hapus atribut "${a.name}"?`)) return;
    setDeletingId(a.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteProductAttribute(a.id);
      setSuccess('Atribut berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus atribut.');
    } finally {
      setDeletingId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const visible = items.filter(
    (a) =>
      (filter === 'all' || (filter === 'system') === a.is_system) &&
      (!q || a.name.toLowerCase().includes(q) || a.code.toLowerCase().includes(q))
  );

  const editing = modal?.editing ?? null;
  const lockStructure = !!editing?.is_system;

  const inputCls =
    'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-5xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Atribut Produk</h1>
            <p className="text-sm text-slate-500">
              Atribut sistem bawaan (SKU, nama, harga, dll.) tidak dapat dihapus. Anda dapat menambah atribut kustom.
            </p>
          </div>
          <div className="flex flex-wrap items-start gap-2">
            <ImportExportActions resource="attributes" onStarted={transfers.track} importHint={IMPORT_HINT} />
            <button
              onClick={openCreate}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah Atribut
            </button>
          </div>
        </div>

        <DataTransferProgress items={transfers.items} resource="attributes" />

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
            placeholder="Cari nama atau kode..."
            className="min-w-[200px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value as typeof filter)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
          >
            <option value="all">Semua atribut</option>
            <option value="system">Sistem</option>
            <option value="custom">Kustom</option>
          </select>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Tidak ada atribut.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Atribut</th>
                  <th className="px-4 py-3">Kode</th>
                  <th className="px-4 py-3">Tipe</th>
                  <th className="px-4 py-3">Jenis</th>
                  <th className="px-4 py-3">Wajib</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((a) => (
                  <tr key={a.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{a.name}</div>
                      {a.type === 'select' && a.options && (
                        <div className="text-xs text-slate-500">{a.options.join(', ')}</div>
                      )}
                      {a.description && <div className="text-xs text-slate-400">{a.description}</div>}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-slate-600">{a.code}</td>
                    <td className="px-4 py-3 text-slate-600">{TYPE_LABELS[a.type]}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          a.is_system ? 'bg-slate-100 text-slate-600' : 'bg-emerald-100 text-emerald-700'
                        }`}
                      >
                        {a.is_system && <Lock className="h-3 w-3" />}
                        {a.is_system ? 'Sistem' : 'Kustom'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{a.is_required ? 'Ya' : '-'}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          a.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                        }`}
                      >
                        {a.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <button
                        onClick={() => openEdit(a)}
                        title="Ubah"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                      {!a.is_system && (
                        <button
                          onClick={() => remove(a)}
                          disabled={deletingId !== null}
                          title="Hapus"
                          className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                        >
                          {deletingId === a.id ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Trash2 className="h-4 w-4" />
                          )}
                        </button>
                      )}
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
                {editing ? `Ubah Atribut${editing.is_system ? ' Sistem' : ''}` : 'Tambah Atribut Kustom'}
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
              <label className="mb-1 block text-xs font-medium text-slate-600">Nama <span className="text-rose-500">*</span></label>
              <input
                value={form.name}
                onChange={(e) =>
                  setForm({
                    ...form,
                    name: e.target.value,
                    code: editing || codeTouched ? form.code : slugCode(e.target.value),
                  })
                }
                required
                maxLength={100}
                placeholder="mis. Warna"
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Kode <span className="text-rose-500">*</span></label>
              <input
                value={form.code}
                onChange={(e) => {
                  setCodeTouched(true);
                  setForm({ ...form, code: e.target.value });
                }}
                disabled={!!editing}
                required
                maxLength={60}
                pattern="[a-z][a-z0-9_]*"
                placeholder="mis. warna"
                className={`${inputCls} font-mono`}
              />
              {!editing && (
                <p className="mt-1 text-[11px] text-slate-400">Huruf kecil, angka, underscore. Tidak dapat diubah setelah dibuat.</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Tipe <span className="text-rose-500">*</span></label>
                <select
                  value={form.type}
                  onChange={(e) => setForm({ ...form, type: e.target.value as ProductAttributeType })}
                  disabled={lockStructure}
                  className={inputCls}
                >
                  {Object.entries(TYPE_LABELS).map(([v, l]) => (
                    <option key={v} value={v}>
                      {l}
                    </option>
                  ))}
                </select>
              </div>
              <div className="flex flex-col justify-end gap-2 pb-1.5 text-sm text-slate-700">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={form.is_required}
                    disabled={lockStructure}
                    onChange={(e) => setForm({ ...form, is_required: e.target.checked })}
                  />
                  Wajib diisi
                </label>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    disabled={!!editing?.is_system && editing.is_required}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                  />
                  Aktif
                </label>
              </div>
            </div>

            {form.type === 'select' && !lockStructure && (
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Opsi (satu per baris) <span className="text-rose-500">*</span></label>
                <textarea
                  value={form.optionsText}
                  onChange={(e) => setForm({ ...form, optionsText: e.target.value })}
                  rows={4}
                  required
                  placeholder={'Merah\nBiru\nHijau'}
                  className={inputCls}
                />
              </div>
            )}

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Deskripsi (opsional)</label>
              <input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                maxLength={255}
                className={inputCls}
              />
            </div>

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
