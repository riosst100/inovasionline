'use client';

import React, { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import NoWarehouseNotice from '../../../../components/warehouses/NoWarehouseNotice';
import AdminLayout from '../../../../components/layout/AdminLayout';
import SearchableSelect from '../../../../components/ui/SearchableSelect';
import { adminApi } from '../../../../lib/api';
import { Brand, Supplier } from '../../../../types';
import CostHint from '../CostHint';
import { ArrowLeft, ImagePlus, Loader2, Pencil, Plus, Star, Trash2, Warehouse } from 'lucide-react';

const STATUSES: Record<string, string> = {
  active: 'Aktif',
  draft: 'Draft',
  inactive: 'Nonaktif',
  out_of_stock: 'Stok Habis',
  archived: 'Arsip',
};

const toDigits = (v: unknown) => String(v ?? '').replace(/\D/g, '');
const formatRupiah = (v: unknown) => {
  const d = toDigits(v);
  return d ? Number(d).toLocaleString('id-ID') : '';
};
const initPrice = (v: unknown) => (v == null || v === '' ? '' : String(Math.round(Number(v))));

const inputCls = 'mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm';

function EditProductPageContent() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [product, setProduct] = useState<any | null>(null);
  const [categories, setCategories] = useState<any[]>([]);
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [form, setForm] = useState<Record<string, any>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [warehouses, setWarehouses] = useState<any[]>([]);
  const [rows, setRows] = useState<{ warehouse_id: string; quantity: string }[]>([]);
  const [imgBusy, setImgBusy] = useState(false);
  const [imgError, setImgError] = useState('');

  useEffect(() => {
    Promise.all([
      adminApi.getProduct(id),
      adminApi.getCategories().catch(() => []),
      adminApi.getWarehouses().catch(() => []),
      adminApi.getSuppliers().catch(() => []),
      adminApi.getBrands().catch(() => []),
    ])
      .then(([p, cats, whs, sups, brs]: any[]) => {
        setProduct(p);
        setCategories(Array.isArray(cats) ? cats : cats?.data ?? []);
        // Keep the current pick listed even if it has since been deactivated.
        setSuppliers((sups as Supplier[]).filter((s) => s.is_active || s.id === p.supplier_id));
        setBrands((brs as Brand[]).filter((b) => b.is_active || b.id === p.brand_id));
        const whList = Array.isArray(whs) ? whs : whs?.data ?? [];
        setWarehouses(whList.filter((w: any) => w.is_active !== false));
        const initial = (p.stocks ?? []).map((r: any) => ({
          warehouse_id: String(r.warehouse_id),
          quantity: String(r.quantity),
        }));
        setRows(initial);
        setForm({
          name: p.name ?? '',
          category_id: p.category_id ?? '',
          supplier_id: p.supplier_id ?? '',
          brand_id: p.brand_id ?? '',
          short_description: p.short_description ?? '',
          description: p.description ?? '',
          regular_price: initPrice(p.regular_price),
          sale_price: initPrice(p.sale_price),
          cost_price: initPrice(p.cost_price),
          sku: p.sku ?? '',
          status: p.status ?? 'draft',
        });
      })
      .catch((err: any) => setError(err?.message || 'Produk tidak ditemukan.'))
      .finally(() => setLoading(false));
  }, [id]);

  useEffect(() => {
    if (!loading && window.location.hash === '#stok') {
      document.getElementById('stok')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [loading]);

  const setField = (key: string, value: any) => setForm((f) => ({ ...f, [key]: value }));

  const imageAction = async (fn: () => Promise<any>) => {
    setImgBusy(true);
    setImgError('');
    try {
      const updated = await fn();
      setProduct((p: any) => ({ ...p, images: updated.images, image_url: updated.image_url }));
    } catch (err: any) {
      const first = err?.errors ? Object.values(err.errors as Record<string, string[]>)[0]?.[0] : null;
      setImgError(first || err?.message || 'Gagal memproses gambar.');
    } finally {
      setImgBusy(false);
    }
  };

  const onUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []);
    e.target.value = '';
    if (files.length) imageAction(() => adminApi.uploadProductImages(id, files));
  };

  const removeImage = (imageId: string) => {
    if (!confirm('Hapus gambar ini?')) return;
    imageAction(() => adminApi.deleteProductImage(id, imageId));
  };

  const totalStock = rows.reduce((sum, r) => sum + (Number(r.quantity) || 0), 0);
  const updateRow = (i: number, patch: Partial<{ warehouse_id: string; quantity: string }>) =>
    setRows((rs) => rs.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));
  const addRow = () => {
    const free = warehouses.find((w) => !rows.some((r) => r.warehouse_id === String(w.id)));
    if (free) setRows((rs) => [...rs, { warehouse_id: String(free.id), quantity: '0' }]);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await adminApi.updateProduct(id, {
        ...form,
        category_id: form.category_id || null,
        supplier_id: form.supplier_id || null,
        brand_id: form.brand_id || null,
        sale_price: form.sale_price === '' ? null : form.sale_price,
        cost_price: form.cost_price === '' ? null : form.cost_price,
        sku: form.sku || null,
        ...(warehouses.length > 0
          ? { stocks: rows.map((r) => ({ warehouse_id: r.warehouse_id, quantity: Number(r.quantity) || 0 })) }
          : {}),
      });
      router.push('/dashboard/products');
    } catch (err: any) {
      const first = err?.errors ? Object.values(err.errors as Record<string, string[]>)[0]?.[0] : null;
      setError(first || err?.message || 'Gagal menyimpan produk.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <Link href="/dashboard/products" className="inline-flex items-center gap-1 text-xs font-semibold text-slate-500 hover:text-slate-800">
            <ArrowLeft className="h-3.5 w-3.5" /> Kembali ke Produk
          </Link>
          <div className="mt-2 flex items-center gap-2">
            <Pencil className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">Edit Produk</h2>
          </div>
        </div>

        {loading ? (
          <div className="py-12 flex justify-center text-emerald-600">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : !product ? (
          <p className="text-sm text-red-600">{error}</p>
        ) : (
          <>
          <section className="space-y-3 rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-extrabold text-slate-900">Gambar Produk</h3>
              <label className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white ${imgBusy ? 'pointer-events-none opacity-50' : ''}`}>
                {imgBusy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <ImagePlus className="h-3.5 w-3.5" />}
                Tambah Gambar
                <input type="file" accept="image/jpeg,image/png,image/webp" multiple className="hidden" onChange={onUpload} />
              </label>
            </div>
            {imgError && <p className="text-xs text-red-600">{imgError}</p>}
            {(product.images ?? []).length === 0 ? (
              <p className="py-6 text-center text-xs text-slate-400">Belum ada gambar. JPG/PNG/WebP, maks 5 MB per file.</p>
            ) : (
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {product.images.map((img: any) => (
                  <div key={img.id} className="relative aspect-square overflow-hidden rounded-xl border border-slate-200 bg-slate-100">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={img.url} alt={product.name} className="h-full w-full object-cover" />
                    {img.is_primary && (
                      <span className="absolute left-1.5 top-1.5 rounded-md bg-emerald-600 px-1.5 py-0.5 text-[10px] font-bold text-white">Utama</span>
                    )}
                    <div className="absolute inset-x-0 bottom-0 flex justify-end gap-1 bg-black/50 p-1.5">
                      {!img.is_primary && (
                        <button type="button" disabled={imgBusy} title="Jadikan utama" onClick={() => imageAction(() => adminApi.setPrimaryProductImage(id, img.id))} className="rounded-md bg-white/90 p-1 text-amber-600">
                          <Star className="h-3.5 w-3.5" />
                        </button>
                      )}
                      <button type="button" disabled={imgBusy} title="Hapus" onClick={() => removeImage(img.id)} className="rounded-md bg-white/90 p-1 text-rose-600">
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
          <form onSubmit={save} className="space-y-6">
            <div className="space-y-4 rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs">
            <label className="block text-xs font-semibold text-slate-600">
              Nama
              <input required value={form.name} onChange={(e) => setField('name', e.target.value)} className={inputCls} />
            </label>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="block text-xs font-semibold text-slate-600">
                Kategori
                <SearchableSelect
                  value={String(form.category_id ?? '')}
                  onChange={(v) => setField('category_id', v)}
                  options={categories.map((c) => ({ value: String(c.id), label: c.name }))}
                  emptyLabel="- Tanpa kategori -"
                />
              </div>
              <div className="block text-xs font-semibold text-slate-600">
                Supplier
                <SearchableSelect
                  value={String(form.supplier_id ?? '')}
                  onChange={(v) => setField('supplier_id', v)}
                  options={suppliers.map((s) => ({ value: s.id, label: s.name }))}
                  emptyLabel="- Tanpa supplier -"
                />
              </div>
              <div className="block text-xs font-semibold text-slate-600">
                Brand (opsional)
                <SearchableSelect
                  value={String(form.brand_id ?? '')}
                  onChange={(v) => setField('brand_id', v)}
                  options={brands.map((b) => ({ value: b.id, label: b.name }))}
                  emptyLabel="- Tanpa brand -"
                />
              </div>
              <label className="block text-xs font-semibold text-slate-600">
                Status
                <select value={form.status} onChange={(e) => setField('status', e.target.value)} className={inputCls}>
                  {Object.entries(STATUSES).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block text-xs font-semibold text-slate-600">
                Harga Normal
                <div className="relative">
                  <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
                  <input inputMode="numeric" required value={formatRupiah(form.regular_price)} onChange={(e) => setField('regular_price', toDigits(e.target.value))} className={`${inputCls} pl-9`} />
                </div>
              </label>
              <label className="block text-xs font-semibold text-slate-600">
                Harga Diskon
                <div className="relative">
                  <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
                  <input inputMode="numeric" value={formatRupiah(form.sale_price)} onChange={(e) => setField('sale_price', toDigits(e.target.value))} className={`${inputCls} pl-9`} />
                </div>
              </label>
              <label className="block text-xs font-semibold text-slate-600">
                Harga Modal
                <div className="relative">
                  <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
                  <input inputMode="numeric" value={formatRupiah(form.cost_price)} onChange={(e) => setField('cost_price', toDigits(e.target.value))} className={`${inputCls} pl-9`} />
                </div>
                <CostHint price={form.sale_price || form.regular_price} cost={form.cost_price} />
              </label>
              <label className="block text-xs font-semibold text-slate-600">
                SKU
                <input value={form.sku} onChange={(e) => setField('sku', e.target.value)} className={inputCls} />
              </label>
            </div>

            <label className="block text-xs font-semibold text-slate-600">
              Deskripsi Singkat
              <input value={form.short_description} onChange={(e) => setField('short_description', e.target.value)} className={inputCls} />
            </label>
            <label className="block text-xs font-semibold text-slate-600">
              Deskripsi
              <textarea rows={6} value={form.description} onChange={(e) => setField('description', e.target.value)} className={inputCls} />
            </label>

            </div>

            <section id="stok" className="space-y-3 rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-sm font-extrabold text-slate-900">
                  <Warehouse className="h-4 w-4 text-emerald-600" /> Stok
                </div>
                {warehouses.length > 0 && (
                  <span className="text-xs text-slate-500">
                    Total tersedia: <b className="text-slate-800">{totalStock}</b>
                  </span>
                )}
              </div>

              {warehouses.length === 0 ? (
                <NoWarehouseNotice />
              ) : (
                <>
                  {rows.length === 0 && (
                    <p className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
                      Produk ini belum ada di gudang manapun. Tambahkan gudang lalu isi stoknya.
                    </p>
                  )}
                  {rows.map((row, i) => (
                    <div key={i} className="grid grid-cols-[1fr_7rem_auto] items-end gap-2">
                      <div className="text-xs font-semibold text-slate-600">
                        {i === 0 && 'Gudang'}
                        <SearchableSelect
                          value={row.warehouse_id}
                          onChange={(v) => updateRow(i, { warehouse_id: v })}
                          options={warehouses
                            .filter((w) => String(w.id) === row.warehouse_id || !rows.some((r) => r.warehouse_id === String(w.id)))
                            .map((w) => ({ value: String(w.id), label: `${w.name} (${w.code})` }))}
                        />
                      </div>
                      <label className="block text-xs font-semibold text-slate-600">
                        {i === 0 && 'Stok'}
                        <input inputMode="numeric" value={row.quantity} onChange={(e) => updateRow(i, { quantity: toDigits(e.target.value) })} className={inputCls} />
                      </label>
                      <button type="button" title="Hapus" onClick={() => setRows((rs) => rs.filter((_, idx) => idx !== i))} className="mb-1 rounded-lg p-2 text-rose-600 hover:bg-rose-50">
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={addRow}
                    disabled={rows.length >= warehouses.length}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-slate-300 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-40"
                  >
                    <Plus className="h-3.5 w-3.5" /> Tambah Gudang
                  </button>
                </>
              )}
            </section>

            {error && <p className="text-xs text-red-600">{error}</p>}

            <div className="flex justify-end gap-2">
              <Link href="/dashboard/products" className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600">
                Batal
              </Link>
              <button type="submit" disabled={saving} className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">
                {saving && <Loader2 className="h-4 w-4 animate-spin" />} Simpan
              </button>
            </div>
          </form>
          </>
        )}
      </div>
    </AdminLayout>
  );
}

// useParams() must sit inside <Suspense> or prerendering the dynamic route fails the build.
export default function EditProductPage() {
  return (
    <Suspense>
      <EditProductPageContent />
    </Suspense>
  );
}
