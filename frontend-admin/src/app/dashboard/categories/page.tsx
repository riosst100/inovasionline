'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import ImportExportActions from '../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../components/data-transfer/DataTransferProgress';
import { adminApi } from '../../../lib/api';
import { useDataTransfers } from '../../../lib/dataTransfer';
import { DataTransfer } from '../../../types';
import { FolderTree, GripVertical, ImageIcon, Loader2, Plus, X } from 'lucide-react';

const IMPORT_HINT = (
  <>
    Kolom: <b>name</b> (wajib), slug, parent (slug/nama kategori induk), description, image_url, sort_order,
    is_active (1/0). Baris dengan slug yang sudah ada akan <b>diperbarui</b>, selain itu dibuat baru.
  </>
);

type CategoryForm = {
  id?: string;
  name: string;
  is_active: boolean;
  image: File | null;
  preview: string | null;
};

const emptyForm: CategoryForm = {
  name: '',
  is_active: true,
  image: null,
  preview: null,
};

export default function AdminCategoriesPage() {
  const [categories, setCategories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState<CategoryForm | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setLoading(true);
    adminApi
      .getCategories()
      .then((data: any) => setCategories(Array.isArray(data) ? data : data?.data ?? []))
      .catch(() => setCategories([]))
      .finally(() => setLoading(false));
  }, []);

  useEffect(load, [load]);

  const onTransferFinished = useCallback(
    (t: DataTransfer) => {
      if (t.type === 'import' && t.status === 'completed') load();
    },
    [load]
  );
  const transfers = useDataTransfers({ resource: 'categories', perPage: 5 }, onTransferFinished);

  const [dragId, setDragId] = useState<string | null>(null);
  const [overId, setOverId] = useState<string | null>(null);

  const drop = async (targetId: string) => {
    const from = categories.findIndex((c) => c.id === dragId);
    const to = categories.findIndex((c) => c.id === targetId);
    setDragId(null);
    setOverId(null);
    if (from < 0 || to < 0 || from === to) return;

    const previous = categories;
    const next = [...categories];
    next.splice(to, 0, next.splice(from, 1)[0]);
    setCategories(next);
    try {
      await adminApi.reorderCategories(next.map((c) => c.id));
    } catch (err: any) {
      setCategories(previous);
      setError(err?.message || 'Gagal menyimpan urutan.');
    }
  };

  const openEdit = (c: any) =>
    setForm({
      id: c.id,
      name: c.name,
      is_active: !!c.is_active,
      image: null,
      preview: c.image_url ?? null,
    });

  const toggle = async (c: any) => {
    const previous = categories;
    setCategories(categories.map((x) => (x.id === c.id ? { ...x, is_active: !x.is_active } : x)));
    try {
      await adminApi.toggleCategory(c.id);
    } catch (err: any) {
      setCategories(previous);
      setError(err?.message || 'Gagal mengubah status kategori.');
    }
  };

  const remove = async () => {
    if (!form?.id) return;
    if (!window.confirm(`Hapus kategori "${form.name}"?`)) return;
    setSaving(true);
    setError('');
    try {
      await adminApi.deleteCategory(form.id);
      setForm(null);
      load();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus kategori.');
    } finally {
      setSaving(false);
    }
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form) return;
    setSaving(true);
    setError('');
    try {
      const body = new FormData();
      body.append('name', form.name);
      body.append('is_active', form.is_active ? '1' : '0');
      if (form.image) body.append('image', form.image);
      await adminApi.saveCategory(body, form.id);
      setForm(null);
      load();
    } catch (err: any) {
      const details = err?.errors ? Object.values(err.errors).flat().join(' ') : '';
      setError(`${err?.message || 'Gagal menyimpan kategori.'} ${details}`.trim());
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <FolderTree className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                Katalog Kategori Produk
              </h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Kategori dan gambar di sini tampil langsung di aplikasi. Seret kartu untuk mengatur urutan.
            </p>
            {error && !form && <p className="mt-1 text-xs text-red-600">{error}</p>}
          </div>
          <div className="flex flex-wrap items-start justify-end gap-2">
            <ImportExportActions resource="categories" onStarted={transfers.track} importHint={IMPORT_HINT} />
            <button
              onClick={() => {
                setError('');
                setForm(emptyForm);
              }}
              className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-3 py-2 text-xs font-bold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah
            </button>
          </div>
        </div>

        <DataTransferProgress items={transfers.items} resource="categories" />

        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          {loading ? (
            <div className="py-12 flex justify-center text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : categories.length === 0 ? (
            <div className="py-12 text-center text-slate-400 text-sm">
              Belum ada kategori terdaftar.
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
              {categories.map((c) => (
                <div
                  key={c.id}
                  onDragOver={(e) => {
                    if (!dragId) return;
                    e.preventDefault();
                    setOverId(c.id);
                  }}
                  onDrop={() => drop(c.id)}
                  className={`relative rounded-xl border bg-slate-50 hover:border-emerald-300 transition-colors ${
                    overId === c.id && dragId !== c.id ? 'border-emerald-500 ring-2 ring-emerald-200' : 'border-slate-100'
                  } ${dragId === c.id ? 'opacity-40' : c.is_active ? '' : 'opacity-50'}`}
                >
                  <span
                    draggable
                    title="Seret untuk mengubah urutan"
                    onDragStart={(e) => {
                      const card = e.currentTarget.parentElement;
                      if (card) e.dataTransfer.setDragImage(card, 20, 20);
                      e.dataTransfer.effectAllowed = 'move';
                      setDragId(c.id);
                    }}
                    onDragEnd={() => {
                      setDragId(null);
                      setOverId(null);
                    }}
                    className="absolute right-1.5 top-1.5 z-10 cursor-grab rounded-md p-1 text-slate-400 hover:bg-slate-200 hover:text-slate-600 active:cursor-grabbing"
                  >
                    <GripVertical className="h-4 w-4" />
                  </span>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={!!c.is_active}
                    title={c.is_active ? 'Nonaktifkan kategori' : 'Aktifkan kategori'}
                    onClick={() => toggle(c)}
                    className={`absolute left-2 top-2 z-10 h-4 w-7 rounded-full transition-colors ${
                      c.is_active ? 'bg-emerald-500' : 'bg-slate-300'
                    }`}
                  >
                    <span
                      className={`absolute top-0.5 h-3 w-3 rounded-full bg-white shadow transition-all ${
                        c.is_active ? 'left-3.5' : 'left-0.5'
                      }`}
                    />
                  </button>
                  <button
                    onClick={() => openEdit(c)}
                    className="flex w-full flex-col items-center justify-center p-4 text-center"
                  >
                    <div className="h-14 w-14 rounded-xl bg-emerald-100 flex items-center justify-center overflow-hidden text-2xl mb-2">
                      {c.image_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={c.image_url} alt={c.name} className="h-full w-full object-cover" draggable={false} />
                      ) : (
                        <ImageIcon className="h-6 w-6 text-emerald-400" />
                      )}
                    </div>
                    <span className="text-xs font-bold text-slate-800 line-clamp-1">{c.name}</span>
                    {!c.is_active && <span className="text-[10px] text-slate-400">Nonaktif</span>}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <form onSubmit={submit} className="w-full max-w-md space-y-4 rounded-2xl bg-white p-6 shadow-xl">
            <div className="flex items-center justify-between">
              <h3 className="font-extrabold text-slate-900">{form.id ? 'Ubah Kategori' : 'Tambah Kategori'}</h3>
              <button type="button" onClick={() => setForm(null)}>
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <label className="block text-xs font-bold text-slate-700">
              Nama <span className="text-rose-500">*</span>
              <input
                required
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
              />
            </label>

            <label className="block text-xs font-bold text-slate-700">
              Gambar
              <input
                type="file"
                accept="image/*"
                onChange={(e) => {
                  const file = e.target.files?.[0] ?? null;
                  setForm({ ...form, image: file, preview: file ? URL.createObjectURL(file) : form.preview });
                }}
                className="mt-1 block w-full text-xs"
              />
            </label>
            {form.preview && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={form.preview} alt="Pratinjau" className="h-20 w-20 rounded-xl object-cover" />
            )}

            <label className="flex items-center gap-2 text-xs font-bold text-slate-700">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
              />
              Aktif (tampil di aplikasi)
            </label>

            {error && <p className="text-xs text-red-600">{error}</p>}

            <button
              disabled={saving}
              className="w-full rounded-xl bg-emerald-600 py-2.5 text-sm font-bold text-white hover:bg-emerald-700 disabled:opacity-60"
            >
              {saving ? 'Menyimpan...' : 'Simpan'}
            </button>
            {form.id && (
              <button
                type="button"
                disabled={saving}
                onClick={remove}
                className="w-full rounded-xl border border-red-200 py-2.5 text-sm font-bold text-red-600 hover:bg-red-50 disabled:opacity-60"
              >
                Hapus Kategori
              </button>
            )}
          </form>
        </div>
      )}
    </AdminLayout>
  );
}
