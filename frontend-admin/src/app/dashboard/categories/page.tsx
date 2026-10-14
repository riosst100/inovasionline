'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi } from '../../../lib/api';
import { FolderTree, Loader2, Plus, X } from 'lucide-react';

type CategoryForm = {
  id?: string;
  name: string;
  icon: string;
  sort_order: string;
  is_active: boolean;
  image: File | null;
  preview: string | null;
};

const emptyForm: CategoryForm = {
  name: '',
  icon: '',
  sort_order: '',
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

  const openEdit = (c: any) =>
    setForm({
      id: c.id,
      name: c.name,
      icon: c.icon ?? '',
      sort_order: c.sort_order != null ? String(c.sort_order) : '',
      is_active: !!c.is_active,
      image: null,
      preview: c.image_url ?? null,
    });

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form) return;
    setSaving(true);
    setError('');
    try {
      const body = new FormData();
      body.append('name', form.name);
      body.append('icon', form.icon);
      if (form.sort_order !== '') body.append('sort_order', form.sort_order);
      body.append('is_active', form.is_active ? '1' : '0');
      if (form.image) body.append('image', form.image);
      await adminApi.saveCategory(body, form.id);
      setForm(null);
      load();
    } catch (err: any) {
      setError(err?.message || 'Gagal menyimpan kategori.');
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
              Kategori dan gambar di sini tampil langsung di aplikasi.
            </p>
          </div>
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
                <button
                  key={c.id}
                  onClick={() => openEdit(c)}
                  className={`flex flex-col items-center justify-center p-4 rounded-xl border border-slate-100 bg-slate-50 hover:border-emerald-300 transition-colors text-center ${
                    c.is_active ? '' : 'opacity-50'
                  }`}
                >
                  <div className="h-14 w-14 rounded-xl bg-emerald-100 flex items-center justify-center overflow-hidden text-2xl mb-2">
                    {c.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={c.image_url} alt={c.name} className="h-full w-full object-cover" />
                    ) : (
                      c.icon || c.name.slice(0, 2)
                    )}
                  </div>
                  <span className="text-xs font-bold text-slate-800 line-clamp-1">{c.name}</span>
                  {!c.is_active && <span className="text-[10px] text-slate-400">Nonaktif</span>}
                </button>
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
              Nama
              <input
                required
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
              />
            </label>

            <div className="grid grid-cols-2 gap-3">
              <label className="block text-xs font-bold text-slate-700">
                Ikon (emoji)
                <input
                  value={form.icon}
                  onChange={(e) => setForm({ ...form, icon: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
                />
              </label>
              <label className="block text-xs font-bold text-slate-700">
                Urutan
                <input
                  type="number"
                  min={0}
                  value={form.sort_order}
                  onChange={(e) => setForm({ ...form, sort_order: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm"
                />
              </label>
            </div>

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
          </form>
        </div>
      )}
    </AdminLayout>
  );
}
