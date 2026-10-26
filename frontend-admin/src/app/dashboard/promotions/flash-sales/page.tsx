'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { formatDate, formatTime, fromWib, sameWibDay, todayWib, wibParts } from '../../../../lib/date';
import { adminApi, ApiError } from '../../../../lib/api';
import { FlashSale, FlashSaleStatus, PaginationMeta } from '../../../../types';
import {
  AlertCircle,
  CalendarClock,
  CheckCircle2,
  ImageOff,
  Loader2,
  Pencil,
  Plus,
  Power,
  Search,
  Trash2,
  X,
  Zap,
} from 'lucide-react';

const rupiah = (n: number) => `Rp${Math.round(n).toLocaleString('id-ID')}`;

const STATUS: Record<FlashSaleStatus, { label: string; className: string }> = {
  running: { label: 'Berlangsung', className: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  upcoming: { label: 'Akan Datang', className: 'bg-sky-50 text-sky-700 border-sky-200' },
  ended: { label: 'Selesai', className: 'bg-slate-100 text-slate-500 border-slate-200' },
  inactive: { label: 'Nonaktif', className: 'bg-amber-50 text-amber-700 border-amber-200' },
};

const FILTERS: { value: '' | FlashSaleStatus; label: string }[] = [
  { value: '', label: 'Semua' },
  { value: 'running', label: 'Berlangsung' },
  { value: 'upcoming', label: 'Akan Datang' },
  { value: 'ended', label: 'Selesai' },
  { value: 'inactive', label: 'Nonaktif' },
];

const formatSchedule = (startsAt: string, endsAt: string) =>
  sameWibDay(startsAt, endsAt)
    ? `${formatDate(startsAt)}, ${formatTime(startsAt)} – ${formatTime(endsAt)}`
    : `${formatDate(startsAt)} ${formatTime(startsAt)} – ${formatDate(endsAt)} ${formatTime(endsAt)}`;

/** Row from /admin/products used by the picker. */
type ProductOption = {
  id: string;
  name: string;
  sku?: string | null;
  image_url?: string | null;
  regular_price: number | string;
  stock?: number;
};

type PickedProduct = {
  product_id: string;
  name: string;
  sku: string | null;
  image_url: string | null;
  regular_price: number;
  flash_sale_price: string;
};

type FormState = {
  name: string;
  start_date: string;
  start_time: string;
  end_date: string;
  end_time: string;
  is_active: boolean;
  products: PickedProduct[];
};

const blankForm: FormState = {
  name: '',
  start_date: '',
  start_time: '',
  end_date: '',
  end_time: '',
  is_active: true,
  products: [],
};

/** Reads the clock, so only call it from event handlers (not during render/prerender). */
function emptyForm(): FormState {
  const today = todayWib();
  return {
    name: '',
    start_date: today,
    start_time: '12:00',
    end_date: today,
    end_time: '14:00',
    is_active: true,
    products: [],
  };
}

export default function FlashSalesPage() {
  const [items, setItems] = useState<FlashSale[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState<'' | FlashSaleStatus>('');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [modal, setModal] = useState<{ editingId: string | null } | null>(null);
  const [form, setForm] = useState<FormState>(blankForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);

  const [productQuery, setProductQuery] = useState('');
  const [productResults, setProductResults] = useState<ProductOption[]>([]);
  const [searchingProducts, setSearchingProducts] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.getFlashSales({ search, status, page });
      setItems(res.data);
      setMeta(res.meta ?? null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat flash sale.');
    } finally {
      setLoading(false);
    }
  }, [search, status, page]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  // Product picker: debounced search over active products.
  useEffect(() => {
    if (!modal) return;
    let cancelled = false;
    const t = setTimeout(async () => {
      setSearchingProducts(true);
      try {
        const res = await adminApi.getProducts(productQuery, 'active');
        if (!cancelled) setProductResults(res);
      } catch {
        if (!cancelled) setProductResults([]);
      } finally {
        if (!cancelled) setSearchingProducts(false);
      }
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(t);
    };
  }, [productQuery, modal]);

  const openCreate = () => {
    setForm(emptyForm());
    setFormError(null);
    setProductQuery('');
    setModal({ editingId: null });
  };

  const openEdit = async (item: FlashSale) => {
    setFormError(null);
    setProductQuery('');
    setModal({ editingId: item.id });
    setLoadingDetail(true);
    try {
      const detail = await adminApi.getFlashSale(item.id);
      const start = wibParts(detail.starts_at);
      const end = wibParts(detail.ends_at);
      setForm({
        name: detail.name,
        start_date: start.date,
        start_time: start.time,
        end_date: end.date,
        end_time: end.time,
        is_active: detail.is_active,
        products: (detail.products ?? []).map((p) => ({
          product_id: p.product_id,
          name: p.name,
          sku: p.sku,
          image_url: p.image_url,
          regular_price: p.regular_price,
          flash_sale_price: p.flash_sale_price !== null ? String(Math.round(p.flash_sale_price)) : '',
        })),
      });
    } catch (e) {
      setFormError(e instanceof ApiError ? e.message : 'Gagal memuat detail flash sale.');
    } finally {
      setLoadingDetail(false);
    }
  };

  const addProduct = (p: ProductOption) => {
    if (form.products.some((x) => x.product_id === p.id)) return;
    setForm((f) => ({
      ...f,
      products: [
        ...f.products,
        {
          product_id: p.id,
          name: p.name,
          sku: p.sku ?? null,
          image_url: p.image_url ?? null,
          regular_price: Number(p.regular_price),
          flash_sale_price: '',
        },
      ],
    }));
  };

  const updatePrice = (productId: string, value: string) =>
    setForm((f) => ({
      ...f,
      products: f.products.map((p) => (p.product_id === productId ? { ...p, flash_sale_price: value.replace(/\D/g, '') } : p)),
    }));

  const removeProduct = (productId: string) =>
    setForm((f) => ({ ...f, products: f.products.filter((p) => p.product_id !== productId) }));

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    if (form.products.length === 0) return setFormError('Pilih minimal satu produk.');
    const invalid = form.products.find((p) => p.flash_sale_price === '' || Number(p.flash_sale_price) >= p.regular_price);
    if (invalid) return setFormError(`Harga flash sale ${invalid.name} wajib diisi dan harus lebih murah dari harga normal.`);

    const startsAt = fromWib(form.start_date, form.start_time);
    const endsAt = fromWib(form.end_date, form.end_time);
    if (new Date(endsAt) <= new Date(startsAt)) return setFormError('Waktu selesai harus setelah waktu mulai.');

    setSaving(true);
    try {
      await adminApi.saveFlashSale(
        {
          name: form.name.trim(),
          starts_at: startsAt,
          ends_at: endsAt,
          is_active: form.is_active,
          products: form.products.map((p) => ({ product_id: p.product_id, flash_sale_price: Number(p.flash_sale_price) })),
        },
        modal?.editingId ?? undefined
      );
      setSuccess(modal?.editingId ? 'Flash sale berhasil diperbarui.' : 'Flash sale berhasil dibuat.');
      setModal(null);
      load();
    } catch (err) {
      setFormError(
        err instanceof ApiError
          ? (err.errors && Object.values(err.errors)[0]?.[0]) || err.message
          : 'Gagal menyimpan flash sale.'
      );
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (item: FlashSale) => {
    setBusyId(item.id);
    setError(null);
    try {
      await adminApi.toggleFlashSale(item.id);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal mengubah status flash sale.');
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (item: FlashSale) => {
    if (!confirm(`Hapus flash sale "${item.name}"?`)) return;
    setBusyId(item.id);
    setError(null);
    try {
      await adminApi.deleteFlashSale(item.id);
      setSuccess('Flash sale berhasil dihapus.');
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal menghapus flash sale.');
    } finally {
      setBusyId(null);
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Flash Sale</h1>
            <p className="text-sm text-slate-500">
              Harga spesial untuk produk pilihan pada tanggal dan jam tertentu. Harga flash sale otomatis berlaku di
              keranjang dan checkout selama periode berjalan.
            </p>
          </div>
          <button
            type="button"
            onClick={openCreate}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" /> Buat Flash Sale
          </button>
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

        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-1.5">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                type="button"
                onClick={() => {
                  setStatus(f.value);
                  setPage(1);
                }}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  status === f.value ? 'bg-slate-900 text-white' : 'bg-white text-slate-600 hover:bg-slate-100'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              placeholder="Cari nama flash sale..."
              className={`${input} pl-9`}
            />
          </div>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : items.length === 0 ? (
            <div className="flex flex-col items-center p-10 text-center">
              <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
                <Zap className="h-6 w-6" />
              </div>
              <p className="font-semibold text-slate-800">Belum ada flash sale</p>
              <p className="mt-1 text-sm text-slate-500">Klik &quot;Buat Flash Sale&quot; untuk menjadwalkan yang pertama.</p>
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Flash Sale</th>
                  <th className="px-4 py-3">Jadwal</th>
                  <th className="px-4 py-3">Produk</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {items.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/60">
                    <td className="px-4 py-3 font-semibold text-slate-800">{item.name}</td>
                    <td className="px-4 py-3 text-slate-600">
                      <span className="inline-flex items-center gap-1.5">
                        <CalendarClock className="h-4 w-4 text-slate-400" />
                        {formatSchedule(item.starts_at, item.ends_at)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{item.products_count ?? 0} produk</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-md border px-2 py-0.5 text-xs font-semibold ${STATUS[item.status].className}`}>
                        {STATUS[item.status].label}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        <button
                          type="button"
                          onClick={() => toggle(item)}
                          disabled={busyId === item.id}
                          title={item.is_active ? 'Nonaktifkan' : 'Aktifkan'}
                          className={`rounded-lg p-2 hover:bg-slate-100 disabled:opacity-50 ${item.is_active ? 'text-emerald-600' : 'text-slate-400'}`}
                        >
                          <Power className="h-4 w-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => openEdit(item)}
                          title="Ubah"
                          className="rounded-lg p-2 text-slate-500 hover:bg-slate-100"
                        >
                          <Pencil className="h-4 w-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => remove(item)}
                          disabled={busyId === item.id}
                          title="Hapus"
                          className="rounded-lg p-2 text-rose-500 hover:bg-rose-50 disabled:opacity-50"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {meta && meta.last_page > 1 && (
          <div className="flex items-center justify-end gap-2 text-sm">
            <button
              type="button"
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
              className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 disabled:opacity-40"
            >
              Sebelumnya
            </button>
            <span className="text-slate-500">
              {meta.current_page} / {meta.last_page}
            </span>
            <button
              type="button"
              disabled={page >= meta.last_page}
              onClick={() => setPage((p) => p + 1)}
              className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 disabled:opacity-40"
            >
              Berikutnya
            </button>
          </div>
        )}
      </div>

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
          <form
            onSubmit={save}
            className="flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl bg-white shadow-xl"
          >
            <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4">
              <h2 className="text-lg font-bold text-slate-900">
                {modal.editingId ? 'Ubah Flash Sale' : 'Buat Flash Sale'}
              </h2>
              <button type="button" onClick={() => setModal(null)} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
                <X className="h-5 w-5" />
              </button>
            </div>

            {loadingDetail ? (
              <div className="flex justify-center p-12">
                <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
              </div>
            ) : (
              <div className="flex-1 space-y-5 overflow-y-auto px-6 py-5">
                {formError && (
                  <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
                    <AlertCircle className="h-4 w-4 shrink-0" /> {formError}
                  </div>
                )}

                <label className="block space-y-1">
                  <span className="text-sm font-medium text-slate-700">Nama Flash Sale <span className="text-rose-500">*</span></span>
                  <input
                    required
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                    placeholder="mis. Flash Sale 12.12 Siang"
                    className={input}
                  />
                </label>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-1">
                    <span className="text-sm font-medium text-slate-700">Mulai <span className="text-rose-500">*</span></span>
                    <div className="flex gap-2">
                      <input
                        type="date"
                        required
                        value={form.start_date}
                        onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                        className={input}
                      />
                      <input
                        type="time"
                        required
                        value={form.start_time}
                        onChange={(e) => setForm({ ...form, start_time: e.target.value })}
                        className={`${input} w-32`}
                      />
                    </div>
                  </div>
                  <div className="space-y-1">
                    <span className="text-sm font-medium text-slate-700">Selesai <span className="text-rose-500">*</span></span>
                    <div className="flex gap-2">
                      <input
                        type="date"
                        required
                        value={form.end_date}
                        min={form.start_date}
                        onChange={(e) => setForm({ ...form, end_date: e.target.value })}
                        className={input}
                      />
                      <input
                        type="time"
                        required
                        value={form.end_time}
                        onChange={(e) => setForm({ ...form, end_time: e.target.value })}
                        className={`${input} w-32`}
                      />
                    </div>
                  </div>
                </div>

                <label className="flex items-center gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                    className="h-4 w-4 accent-emerald-600"
                  />
                  Aktif
                </label>

                <div className="space-y-2">
                  <span className="text-sm font-medium text-slate-700">
                    Produk Flash Sale <span className="text-rose-500">*</span> <span className="text-slate-400">({form.products.length})</span>
                  </span>

                  {form.products.length === 0 ? (
                    <p className="rounded-xl border border-dashed border-slate-200 p-4 text-center text-sm text-slate-500">
                      Belum ada produk. Cari dan tambahkan produk di bawah.
                    </p>
                  ) : (
                    <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                      {form.products.map((p) => {
                        const price = Number(p.flash_sale_price);
                        const pct =
                          p.flash_sale_price !== '' && p.regular_price > 0 && price < p.regular_price
                            ? Math.round(((p.regular_price - price) / p.regular_price) * 100)
                            : null;
                        const tooHigh = p.flash_sale_price !== '' && price >= p.regular_price;
                        return (
                          <div key={p.product_id} className="flex flex-wrap items-center gap-3 p-3">
                            <Thumb url={p.image_url} />
                            <div className="min-w-0 flex-1">
                              <p className="truncate text-sm font-semibold text-slate-800">{p.name}</p>
                              <p className="text-xs text-slate-500">Harga normal {rupiah(p.regular_price)}</p>
                            </div>
                            <div className="flex items-center gap-2">
                              <div className="relative">
                                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-slate-400">Rp</span>
                                <input
                                  inputMode="numeric"
                                  value={p.flash_sale_price}
                                  onChange={(e) => updatePrice(p.product_id, e.target.value)}
                                  placeholder="Harga flash sale"
                                  className={`${input} w-40 pl-8 ${tooHigh ? 'border-rose-400' : ''}`}
                                />
                              </div>
                              <span
                                className={`w-12 text-right text-xs font-bold ${pct !== null ? 'text-rose-600' : 'text-slate-300'}`}
                              >
                                {pct !== null ? `-${pct}%` : '–'}
                              </span>
                              <button
                                type="button"
                                onClick={() => removeProduct(p.product_id)}
                                title="Hapus produk"
                                className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-500"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}

                  <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-3">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                      <input
                        value={productQuery}
                        onChange={(e) => setProductQuery(e.target.value)}
                        placeholder="Cari produk aktif untuk ditambahkan..."
                        className={`${input} pl-9`}
                      />
                    </div>
                    <div className="mt-2 max-h-56 space-y-1 overflow-y-auto">
                      {searchingProducts ? (
                        <div className="flex justify-center p-4">
                          <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
                        </div>
                      ) : productResults.length === 0 ? (
                        <p className="p-3 text-center text-xs text-slate-500">Produk tidak ditemukan.</p>
                      ) : (
                        productResults.map((p) => {
                          const added = form.products.some((x) => x.product_id === p.id);
                          return (
                            <div key={p.id} className="flex items-center gap-3 rounded-lg bg-white p-2">
                              <Thumb url={p.image_url} />
                              <div className="min-w-0 flex-1">
                                <p className="truncate text-sm text-slate-800">{p.name}</p>
                                <p className="text-xs text-slate-500">
                                  {rupiah(Number(p.regular_price))} · Stok {p.stock ?? 0}
                                </p>
                              </div>
                              <button
                                type="button"
                                disabled={added}
                                onClick={() => addProduct(p)}
                                className="inline-flex items-center gap-1 rounded-lg border border-emerald-200 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-50 disabled:border-slate-200 disabled:text-slate-400 disabled:hover:bg-transparent"
                              >
                                {added ? 'Ditambahkan' : (<><Plus className="h-3.5 w-3.5" /> Tambah</>)}
                              </button>
                            </div>
                          );
                        })
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )}

            <div className="flex justify-end gap-2 border-t border-slate-100 px-6 py-4">
              <button
                type="button"
                onClick={() => setModal(null)}
                className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-50"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={saving || loadingDetail}
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

function Thumb({ url }: { url?: string | null }) {
  return url ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={url} alt="" className="h-10 w-10 shrink-0 rounded-lg border border-slate-100 object-cover" />
  ) : (
    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-slate-100 text-slate-400">
      <ImageOff className="h-4 w-4" />
    </div>
  );
}
