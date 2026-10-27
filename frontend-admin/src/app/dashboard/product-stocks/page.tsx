'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import ImportExportActions from '../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../components/data-transfer/DataTransferProgress';
import { adminApi, ApiError } from '../../../lib/api';
import { useDataTransfers } from '../../../lib/dataTransfer';
import { DataTransfer, ProductStockRow, Warehouse } from '../../../types';

const IMPORT_HINT = (
  <>
    Satu baris per produk per gudang. Kolom: <b>product_id</b> atau <b>sku</b>, <b>warehouse_code</b>, dan{' '}
    <b>quantity</b> (wajib). product_name & warehouse_name hanya informasi. Stok gudang yang tidak ada di file tidak
    berubah; total stok produk dihitung ulang otomatis.
  </>
);
import SearchableSelect from '../../../components/ui/SearchableSelect';
import { AlertCircle, Loader2, Package, Pencil, Plus, Trash2, X } from 'lucide-react';

export default function ProductStocksPage() {
  const [rows, setRows] = useState<ProductStockRow[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [debounced, setDebounced] = useState('');
  const [warehouseId, setWarehouseId] = useState('');
  const [editing, setEditing] = useState<ProductStockRow | null>(null);
  const [editRows, setEditRows] = useState<{ warehouse_id: string; quantity: string }[]>([]);
  const [saving, setSaving] = useState(false);
  const [editError, setEditError] = useState('');
  const [reloadKey, setReloadKey] = useState(0);

  const onTransferFinished = useCallback((t: DataTransfer) => {
    if (t.type === 'import' && t.status === 'completed') setReloadKey((k) => k + 1);
  }, []);
  const transfers = useDataTransfers({ resource: 'product-stocks', perPage: 5 }, onTransferFinished);

  useEffect(() => {
    adminApi.getWarehouses().then(setWarehouses).catch(() => {});
  }, []);

  useEffect(() => {
    const t = setTimeout(() => setDebounced(search), 300);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    adminApi
      .getProductStocks(debounced, warehouseId)
      .then((data) => {
        if (!cancelled) {
          setRows(data);
          setError(null);
        }
      })
      .catch((e) => !cancelled && setError(e instanceof ApiError ? e.message : 'Gagal memuat stok produk.'))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [debounced, warehouseId, reloadKey]);

  const activeWarehouses = warehouses.filter((w) => w.is_active !== false);

  const openEdit = (p: ProductStockRow) => {
    setEditing(p);
    setEditError('');
    setEditRows(p.stocks.map((s) => ({ warehouse_id: String(s.warehouse_id), quantity: String(s.quantity) })));
  };

  const updateRow = (i: number, patch: Partial<{ warehouse_id: string; quantity: string }>) =>
    setEditRows((rs) => rs.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));

  const addRow = () => {
    const free = activeWarehouses.find((w) => !editRows.some((r) => r.warehouse_id === String(w.id)));
    if (free) setEditRows((rs) => [...rs, { warehouse_id: String(free.id), quantity: '0' }]);
  };

  const editTotal = editRows.reduce((sum, r) => sum + (Number(r.quantity) || 0), 0);

  const saveStock = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    setSaving(true);
    setEditError('');
    try {
      const updated = await adminApi.updateProductStock(
        editing.id,
        editRows.map((r) => ({ warehouse_id: r.warehouse_id, quantity: Number(r.quantity) || 0 }))
      );
      setRows((prev) =>
        updated.stocks.length === 0
          ? prev.filter((r) => r.id !== editing.id)
          : prev.map((r) => (r.id === editing.id ? updated : r))
      );
      setEditing(null);
    } catch (err: any) {
      const first = err?.errors ? Object.values(err.errors as Record<string, string[]>)[0]?.[0] : null;
      setEditError(first || err?.message || 'Gagal menyimpan stok.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Stok Produk</h1>
            <p className="text-sm text-slate-500">
              Produk yang stoknya sudah diatur di gudang. Klik ikon pensil untuk mengubah stok per gudang.
            </p>
          </div>
          <ImportExportActions
            resource="product-stocks"
            onStarted={transfers.track}
            exportFilters={{ search: debounced, warehouse_id: warehouseId }}
            importHint={IMPORT_HINT}
          />
        </div>

        <DataTransferProgress items={transfers.items} resource="product-stocks" />

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        <div className="flex flex-wrap gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama produk atau SKU..."
            className="min-w-[200px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <select
            value={warehouseId}
            onChange={(e) => setWarehouseId(e.target.value)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
          >
            <option value="">Semua gudang</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name}
              </option>
            ))}
          </select>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : rows.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">
              Belum ada produk dengan stok di gudang. Atur stok lewat menu Katalog → Produk → ubah produk.
            </p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Produk</th>
                  <th className="px-4 py-3">SKU</th>
                  <th className="px-4 py-3">Stok per Gudang</th>
                  <th className="px-4 py-3 text-right">Total</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((p) => (
                  <tr key={p.id}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {p.image_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.image_url} alt="" className="h-10 w-10 rounded-lg border border-slate-200 object-cover" />
                        ) : (
                          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-400">
                            <Package className="h-5 w-5" />
                          </div>
                        )}
                        <span className="font-medium text-slate-900">{p.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-slate-600">{p.sku || '-'}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-1.5">
                        {p.stocks.map((s) => (
                          <span
                            key={s.warehouse_id}
                            title={s.warehouse_name}
                            className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                              s.quantity === 0 ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            {s.warehouse_name}: <b>{s.quantity}</b>
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span className={`font-semibold ${p.total <= p.min_stock ? 'text-rose-600' : 'text-slate-900'}`}>
                        {p.total}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      <button
                        type="button"
                        title="Ubah stok"
                        onClick={() => openEdit(p)}
                        className="inline-flex rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                      >
                        <Pencil className="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
      {editing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <form
            onSubmit={saveStock}
            className="max-h-full w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-5 shadow-xl"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="text-lg font-extrabold text-slate-900">Ubah Stok</h3>
                <p className="text-xs text-slate-500">{editing.name}</p>
              </div>
              <button type="button" onClick={() => setEditing(null)} aria-label="Tutup">
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <div className="space-y-3">
              {editRows.map((row, i) => (
                <div key={i} className="grid grid-cols-[1fr_7rem_auto] items-end gap-2">
                  <div className="text-xs font-semibold text-slate-600">
                    {i === 0 && <>Gudang <span className="text-rose-500">*</span></>}
                    <SearchableSelect
                      value={row.warehouse_id}
                      onChange={(v) => updateRow(i, { warehouse_id: v })}
                      options={activeWarehouses
                        .filter((w) => String(w.id) === row.warehouse_id || !editRows.some((r) => r.warehouse_id === String(w.id)))
                        .map((w) => ({ value: String(w.id), label: `${w.name} (${w.code})` }))}
                    />
                  </div>
                  <label className="block text-xs font-semibold text-slate-600">
                    {i === 0 && <>Stok <span className="text-rose-500">*</span></>}
                    <input
                      inputMode="numeric"
                      value={row.quantity}
                      onChange={(e) => updateRow(i, { quantity: e.target.value.replace(/\D/g, '') })}
                      className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
                    />
                  </label>
                  <button
                    type="button"
                    title="Hapus"
                    onClick={() => setEditRows((rs) => rs.filter((_, idx) => idx !== i))}
                    className="mb-1 rounded-lg p-2 text-rose-600 hover:bg-rose-50"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
              <button
                type="button"
                onClick={addRow}
                disabled={editRows.length >= activeWarehouses.length}
                className="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-slate-300 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-40"
              >
                <Plus className="h-3.5 w-3.5" /> Tambah Gudang
              </button>
            </div>

            <p className="text-xs text-slate-500">
              Total tersedia: <b className="text-slate-800">{editTotal}</b>
            </p>
            {editError && <p className="text-xs text-red-600">{editError}</p>}

            <div className="flex justify-end gap-2">
              <button type="button" onClick={() => setEditing(null)} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600">
                Batal
              </button>
              <button type="submit" disabled={saving} className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">
                {saving && <Loader2 className="h-4 w-4 animate-spin" />} Simpan
              </button>
            </div>
          </form>
        </div>
      )}
    </AdminLayout>
  );
}
