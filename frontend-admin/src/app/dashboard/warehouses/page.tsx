'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../lib/api';
import { Warehouse, WarehouseType } from '../../../types';
import { AlertCircle, CheckCircle2, ExternalLink, Loader2, MapPin, Pencil, Phone, Plus, Trash2 } from 'lucide-react';

const TYPE_LABELS: Record<WarehouseType, string> = {
  warehouse: 'Gudang',
  hub: 'Hub',
};

export default function WarehousesPage() {
  const [items, setItems] = useState<Warehouse[]>([]);
  const [loading, setLoading] = useState(true);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [filter, setFilter] = useState<'all' | WarehouseType>('all');
  const [search, setSearch] = useState('');

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getWarehouses());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat data gudang / hub.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const remove = async (w: Warehouse) => {
    if (!confirm(`Hapus "${w.name}"?`)) return;
    setDeletingId(w.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteWarehouse(w.id);
      setSuccess('Gudang / hub berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus gudang / hub.');
    } finally {
      setDeletingId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const visible = items.filter(
    (w) =>
      (filter === 'all' || w.type === filter) &&
      (!q ||
        w.name.toLowerCase().includes(q) ||
        w.code.toLowerCase().includes(q) ||
        (w.city ?? '').toLowerCase().includes(q))
  );

  return (
    <AdminLayout>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Gudang / Hub</h1>
            <p className="text-sm text-slate-500">
              Daftar lokasi penyimpanan. Stok produk nantinya dapat berasal dari beberapa gudang / hub.
            </p>
          </div>
          <Link
            href="/dashboard/warehouses/new"
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" /> Tambah Gudang / Hub
          </Link>
        </div>

        {error && (
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
            placeholder="Cari nama, kode, atau kota..."
            className="min-w-[200px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value as typeof filter)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
          >
            <option value="all">Semua tipe</option>
            <option value="warehouse">Gudang</option>
            <option value="hub">Hub</option>
          </select>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada gudang / hub.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Nama</th>
                  <th className="px-4 py-3">Kode</th>
                  <th className="px-4 py-3">Tipe</th>
                  <th className="px-4 py-3">Lokasi</th>
                  <th className="px-4 py-3">Kontak</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((w) => (
                  <tr key={w.id}>
                    <td className="px-4 py-3">
                      <div className="font-medium text-slate-900">{w.name}</div>
                      {w.notes && <div className="text-xs text-slate-400">{w.notes}</div>}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-slate-600">{w.code}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          w.type === 'hub' ? 'bg-violet-100 text-violet-700' : 'bg-amber-100 text-amber-700'
                        }`}
                      >
                        {TYPE_LABELS[w.type]}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      <div className="flex items-start gap-1.5">
                        <MapPin className="mt-0.5 h-3.5 w-3.5 shrink-0 text-slate-400" />
                        <div>
                          {[w.city, w.province].filter(Boolean).join(', ') || '-'}
                          {w.address && <div className="text-xs text-slate-400">{w.address}</div>}
                          {w.latitude !== null && w.longitude !== null && (
                            <a
                              href={`https://www.google.com/maps?q=${w.latitude},${w.longitude}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="mt-0.5 inline-flex items-center gap-1 text-xs text-emerald-600 hover:underline"
                            >
                              Lihat peta <ExternalLink className="h-3 w-3" />
                            </a>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      {w.contact_name || w.contact_phone ? (
                        <div>
                          {w.contact_name}
                          {w.contact_phone && (
                            <div className="flex items-center gap-1 text-xs text-slate-400">
                              <Phone className="h-3 w-3" /> {w.contact_phone}
                            </div>
                          )}
                        </div>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          w.is_active ? 'bg-sky-100 text-sky-700' : 'bg-rose-100 text-rose-700'
                        }`}
                      >
                        {w.is_active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <Link
                        href={`/dashboard/warehouses/${w.id}`}
                        title="Ubah"
                        className="inline-flex rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </Link>
                      <button
                        onClick={() => remove(w)}
                        disabled={deletingId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {deletingId === w.id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <Trash2 className="h-4 w-4" />
                        )}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
