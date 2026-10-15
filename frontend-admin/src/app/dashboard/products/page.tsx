'use client';

import Link from 'next/link';
import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi } from '../../../lib/api';
import { Loader2, Package, Pencil, Plus, Trash2, EyeOff } from 'lucide-react';

const STATUSES: Record<string, { label: string; badge: string }> = {
  active: { label: 'Aktif', badge: 'bg-emerald-100 text-emerald-700' },
  draft: { label: 'Draft', badge: 'bg-slate-100 text-slate-600' },
  inactive: { label: 'Nonaktif', badge: 'bg-amber-100 text-amber-700' },
  out_of_stock: { label: 'Stok Habis', badge: 'bg-orange-100 text-orange-700' },
  archived: { label: 'Arsip', badge: 'bg-rose-100 text-rose-700' },
};

export default function AdminProductsPage() {
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkBusy, setBulkBusy] = useState(false);

  const load = useCallback(() => {
    setLoading(true);
    return adminApi
      .getProducts(search, status)
      .then((data: any) => setProducts(Array.isArray(data) ? data : data?.data ?? []))
      .catch(() => setProducts([]))
      .finally(() => setLoading(false));
  }, [search, status]);

  useEffect(() => {
    const timer = setTimeout(() => {
      setSelected(new Set());
      load();
    }, 300);
    return () => clearTimeout(timer);
  }, [load]);

  const changeStatus = async (id: string, next: string) => {
    setUpdatingId(id);
    setError('');
    try {
      const updated = await adminApi.updateProductStatus(id, next);
      setProducts((prev) =>
        status && updated.status !== status
          ? prev.filter((p) => p.id !== id)
          : prev.map((p) => (p.id === id ? updated : p))
      );
    } catch (err: any) {
      setError(err?.message || 'Gagal mengubah status produk.');
    } finally {
      setUpdatingId(null);
    }
  };

  const allSelected = products.length > 0 && products.every((p) => selected.has(p.id));
  const toggleAll = () => setSelected(allSelected ? new Set() : new Set(products.map((p) => p.id)));
  const toggleOne = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const bulkDisable = async () => {
    if (!confirm(`Nonaktifkan ${selected.size} produk terpilih?`)) return;
    setBulkBusy(true);
    setError('');
    try {
      await adminApi.bulkUpdateProductStatus([...selected], 'inactive');
      setSelected(new Set());
      await load();
    } catch (err: any) {
      setError(err?.message || 'Gagal menonaktifkan produk.');
    } finally {
      setBulkBusy(false);
    }
  };

  const bulkDelete = async () => {
    if (!confirm(`Hapus ${selected.size} produk terpilih? Tindakan ini tidak dapat dibatalkan.`)) return;
    setBulkBusy(true);
    setError('');
    try {
      await adminApi.bulkDeleteProducts([...selected]);
      setSelected(new Set());
      await load();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus produk.');
    } finally {
      setBulkBusy(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Package className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">Katalog Produk</h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Hanya produk berstatus <b>Aktif</b> yang tampil di aplikasi.
            </p>
          </div>
          <div className="flex w-full gap-2 sm:w-auto">
            <Link
              href="/dashboard/products/new"
              className="inline-flex shrink-0 items-center gap-1.5 rounded-xl bg-emerald-600 px-3 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah Produk
            </Link>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm"
            >
              <option value="">Semua status</option>
              {Object.entries(STATUSES).map(([value, s]) => (
                <option key={value} value={value}>
                  {s.label}
                </option>
              ))}
            </select>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari produk..."
              className="min-w-0 flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm sm:w-56"
            />
          </div>
        </div>

        {error && <p className="text-xs text-red-600">{error}</p>}

        {selected.size > 0 && (
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-sm">
            <span className="font-semibold text-emerald-800">{selected.size} produk dipilih</span>
            <button
              onClick={bulkDisable}
              disabled={bulkBusy}
              className="inline-flex items-center gap-1.5 rounded-lg bg-amber-500 px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
            >
              <EyeOff className="h-3.5 w-3.5" /> Nonaktifkan
            </button>
            <button
              onClick={bulkDelete}
              disabled={bulkBusy}
              className="inline-flex items-center gap-1.5 rounded-lg bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
            >
              <Trash2 className="h-3.5 w-3.5" /> Hapus
            </button>
            <button onClick={() => setSelected(new Set())} className="text-xs text-slate-500 underline">
              Batal pilih
            </button>
            {bulkBusy && <Loader2 className="h-4 w-4 animate-spin text-emerald-600" />}
          </div>
        )}

        <div className="rounded-2xl border border-slate-200/80 bg-white shadow-xs overflow-x-auto">
          {loading ? (
            <div className="py-12 flex justify-center text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : products.length === 0 ? (
            <div className="py-12 text-center text-slate-400 text-sm">Belum ada produk.</div>
          ) : (
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3 w-8">
                    <input type="checkbox" checked={allSelected} onChange={toggleAll} aria-label="Pilih semua" />
                  </th>
                  <th className="px-4 py-3">Produk</th>
                  <th className="px-4 py-3">Kategori</th>
                  <th className="px-4 py-3 text-right">Harga</th>
                  <th className="px-4 py-3 text-right">Stok</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {products.map((p) => {
                  const s = STATUSES[p.status] ?? { label: p.status, badge: 'bg-slate-100 text-slate-600' };
                  return (
                    <tr key={p.id} className={selected.has(p.id) ? 'bg-emerald-50/50' : ''}>
                      <td className="px-4 py-3">
                        <input
                          type="checkbox"
                          checked={selected.has(p.id)}
                          onChange={() => toggleOne(p.id)}
                          aria-label={`Pilih ${p.name}`}
                        />
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="h-10 w-10 shrink-0 overflow-hidden rounded-lg bg-slate-100">
                            {p.image_url && (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={p.image_url} alt={p.name} className="h-full w-full object-cover" />
                            )}
                          </div>
                          <span className="font-semibold text-slate-800 line-clamp-1">{p.name}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-slate-600">{p.category_name ?? '-'}</td>
                      <td className="px-4 py-3 text-right text-slate-800">
                        Rp {Number(p.regular_price).toLocaleString('id-ID')}
                      </td>
                      <td className="px-4 py-3 text-right text-slate-600">{p.stock}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span className={`rounded-md px-2 py-0.5 text-[11px] font-semibold ${s.badge}`}>
                            {s.label}
                          </span>
                          <select
                            value={p.status}
                            disabled={updatingId === p.id}
                            onChange={(e) => changeStatus(p.id, e.target.value)}
                            className="rounded-lg border border-slate-200 bg-white px-1.5 py-1 text-xs disabled:opacity-50"
                          >
                            {Object.entries(STATUSES).map(([value, opt]) => (
                              <option key={value} value={value}>
                                {opt.label}
                              </option>
                            ))}
                          </select>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Link
                          href={`/dashboard/products/${p.id}`}
                          className="inline-flex items-center gap-1 rounded-lg border border-slate-200 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                        >
                          <Pencil className="h-3.5 w-3.5" /> Edit
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

    </AdminLayout>
  );
}
